#exe {Cd(__DIR__);;};;
#include "Generic.HC";

class CTinkwaniosSock:CSocket {
  I64 os_sock;
};

I64 TinkwaniosGetAddrInfo(U8 *node,U8*ul,addrinfo *hints=NULL,addrinfo **res) {
  sockaddr_in *addr=CAlloc(sizeof sockaddr_in);
  addrinfo *info=CAlloc(sizeof addrinfo);
  CNetAddr *new=CAlloc(sizeof CNetAddr);
  new->hostname=StrNew(node);
  new->port=0;
  info->ai_family=AF_INET;
  info->ai_canonname=StrNew(node);
  info->ai_addr=addr;
  info->ai_socktype=SOCK_STREAM;
  addr->sin_zero[0](U64*)=new;
  *res=info;
  return 0;
}

socket_addr_resolver=CAlloc(sizeof CAddrResolver);
socket_addr_resolver->getaddrinfo=&TinkwaniosGetAddrInfo;
extern CTinkwaniosSock *TinkwaniosSocket(U16 ,U16);
I64 TinkwaniosAccept(CTinkwaniosSock *_s,sockaddr *src_addr,I64 addr_len) {
  I64 s=_s->os_sock;
  I64 code;
  CTinkwaniosSock *sock;
  if(NetPollForRead(1,&s)==0) {
    code=NetAccept(s,NULL);
    sock=TinkwaniosSocket(0,0);
    sock->os_sock=code;
  } else
    sock=-1;
  return sock;
}
I64 TinkwaniosClose(CTinkwaniosSock *_s) {
  I64 s=_s->os_sock;
  NetClose(s);
  Free(_s);
  return 0;
}
I64 TinkwaniosBind(CTinkwaniosSock *_s,sockaddr_in *src_addr,I64 addr_len) {
  I64 s=_s->os_sock;
  CNetAddr *from=src_addr->sin_zero[0](U64*),*new;
  new=NetAddrNew(from->hostname,htons(src_addr->sin_port));//Update port information
  NetBindIn(s,new);
  NetAddrDel(new);
  return 0;
}
I64 TinkwaniosConnect(CTinkwaniosSock *_s,sockaddr_in *src_addr,I64 addr_len) {
  I64 s=_s->os_sock;
  CNetAddr *from=src_addr->sin_zero[0](U64*),*new;
  new=NetAddrNew(from->hostname,htons(src_addr->sin_port));//Update port information
  NetConnect(s,new);
  NetAddrDel(new);
  return 0;
}
I64 TinkwaniosListen(CTinkwaniosSock *_s,I64 backlog) {
  I64 s=_s->os_sock;
  NetListen(s,backlog);
  return 0;
}
I64 TinkwaniosRecvFrom(CTinkwaniosSock *_s,U8 *buf,I64 len,I64 flags,sockaddr *ul,I64 addrlen) {
//TODO wherefrom
  I64 s=_s->os_sock;
  while(0!=NetPollForRead(1,&s)) {
    if(0==NetPollForHangup(1,&s))
      return -1;
    Sleep(3);
  };
  return NetRead(s,buf,len);
}
I64 TinkwaniosSendTo(CTinkwaniosSock* _s, U8* buf, I64 len, I64 flags, sockaddr* dest_addr, I64 addrlen) {
//TODO whereto
  I64 s=_s->os_sock;
  return NetWrite(s,buf,len);

}
I64 TinkwaniosSockOpt(CTinkwaniosSock* _s, I64 level, I64 optname, U8* optval, I64 optlen) {
//Poop taods
}

CTinkwaniosSock *TinkwaniosSocket(U16 ,U16) {
  CTinkwaniosSock *ret=CAlloc(sizeof CTinkwaniosSock);
  ret->accept=&TinkwaniosAccept;
  ret->bind=&TinkwaniosBind;
  ret->close=&TinkwaniosClose;
  ret->connect=&TinkwaniosConnect;
  ret->listen=&TinkwaniosListen;
  ret->recvfrom=&TinkwaniosRecvFrom;
  ret->sendto=&TinkwaniosSendTo;
  ret->setsockopt=&TinkwaniosSockOpt;
  ret->os_sock=NetSocketNew;
  return ret;
}
RegisterSocketClass(AF_INET,SOCK_STREAM,&TinkwaniosSocket);
/*
I64 sock=create_connection("tinkwanios.com",6667);
sendString(sock,
"NICK clayton\n"
"USER clayotn 0 * :realname\n"
,0);
U8 buf[STR_LEN];
recvLine(sock,buf,STR_LEN,0);
"%s\n",buf;
close(sock);*/