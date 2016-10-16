//
//  ViewController.m
//  socket服务端
//
//  Created by HM on 16/10/15.
//  Copyright © 2016年 HM. All rights reserved.
//

#import "ViewController.h"
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>

@interface ViewController ()
//监听到的客户端ip地址
@property (weak, nonatomic) IBOutlet UILabel *client_ip;
//监听到的客户端端口
@property (weak, nonatomic) IBOutlet UILabel *client_port;
//服务器手动发送消息
@property (weak, nonatomic) IBOutlet UITextField *server_sendMSG;
//显示客户端发来的消息
@property (weak, nonatomic) IBOutlet UITextView *client_showMSG;
//连接状态
@property (nonatomic, weak) IBOutlet UILabel * status;
//监听按钮点击
@property (weak, nonatomic) IBOutlet UIButton *connectBtn;
//记录按钮状态
@property (nonatomic,assign) int flag;
@end

@implementation ViewController
{
    int _serverSocket;
    int _clientSocket;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //开启服务
    [self startServer];
    
}

- (void)startServer{
    //按钮监听是否启动服务
    [self.connectBtn addTarget:self action:@selector(connectBtnEvent:) forControlEvents:UIControlEventTouchUpInside];
}


#pragma mark - 建立监听
- (void)connectAndlistenPort:(int)port{
    
    _serverSocket=socket(AF_INET, SOCK_STREAM , IPPROTO_TCP);
    //如果返回值不为-1,则成功
    if(_serverSocket != -1){
        NSLog(@"socket success");
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));//清零操作
        addr.sin_len=sizeof(addr);
        addr.sin_family=AF_INET;
        addr.sin_port=htons(port);
        addr.sin_addr.s_addr=INADDR_ANY;
        //绑定地址和端口号
        int bindAddr = bind(_serverSocket, (const struct sockaddr *)&addr, sizeof(addr));
        //开始监听
        if (bindAddr == 0) {
            NSLog(@"bind(绑定) success");
            int startListen = listen(_serverSocket, 5);//5为等待连接数目
            if(startListen == 0){
                NSLog(@"listen success");
                
                //回到主线程更新UI
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.status.text = @"监听成功";
                });
                
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.status.text = @"监听失败";
                });
            }
        }
    }
}


#pragma mark - 阻塞直到客户端连接
- (void)accept{
    
    struct sockaddr_in peeraddr;
    socklen_t addrLen;
    addrLen=sizeof(peeraddr);
    NSLog(@"prepare accept");
    
    //接受到客户端clientSocket连接,获取到地址和端口
    int clientSocket=accept(_serverSocket, (struct sockaddr *)&peeraddr, &addrLen);
    _clientSocket = clientSocket;
    if (clientSocket != -1) {
        NSLog(@"accept success,remote address:%s,port:%d",inet_ntoa(peeraddr.sin_addr),ntohs(peeraddr.sin_port));
        //回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.client_ip.text =[NSString stringWithUTF8String:inet_ntoa(peeraddr.sin_addr)];
            self.client_port.text = [NSString stringWithFormat:@"%d",ntohs(peeraddr.sin_port)];
            
        });
        
        char buf[1024];
        size_t len=sizeof(buf);
        
        //接受到客户端消息
        recv(clientSocket, buf, len, 0);
        NSString* str = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
        //主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.client_showMSG.text = str;
            NSLog(@"%@",str);
        });
    }
}

#pragma mark - 关闭socket
- (void)connectBtnEvent:(UIButton *)sender {
    if (self.flag==0) {
        [self.connectBtn setTitle:@"断开连接" forState:UIControlStateNormal];
        dispatch_queue_t SERIAL_QUEUE =  dispatch_queue_create("SERIAL", DISPATCH_QUEUE_SERIAL);
        dispatch_async(SERIAL_QUEUE, ^{
            
            self.flag=1;
            [self connectAndlistenPort:1024];
            while (self.flag) {
                //扫描客户端连接
                [self accept];
            }
        });
        
        
    }else{
        
        [self.connectBtn setTitle:@"启动服务器" forState:UIControlStateNormal];
        self.status.text = @"监听失败";
        shutdown(_clientSocket, SHUT_RDWR);
        shutdown(_serverSocket, SHUT_RDWR);
        close(_clientSocket);
        close(_serverSocket);
        self.flag=0;
    }
}
#pragma mark - 发送消息

- (IBAction)sendBtn:(UIButton *)sender {
    
    [self sentAndRecv:_clientSocket msg:_server_sendMSG.text];
}

//发送数据并等待返回数据
- (void)sentAndRecv:(int)clientSocket msg:(NSString *)msg {
    dispatch_queue_t q_con =  dispatch_queue_create("CONCURRENT", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(q_con, ^{
        
        const char *str = msg.UTF8String;
        send(clientSocket, str, strlen(str), 0);
        
        char *buf[1024];
        ssize_t recvLen = recv(clientSocket, buf, sizeof(buf), 0);
        
        NSString *recvStr = [[NSString alloc] initWithBytes:buf length:recvLen encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.client_showMSG.text = recvStr;
        });
        
    });
}


@end
