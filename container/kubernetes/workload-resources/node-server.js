const { createServer } = require('http');
var url = require("url");
const os = require('os');

const HOST = '0.0.0.0';
const PORT = 8080;

var healthVar = true;

function querHostIp() {
	// 服务器本机地址
	const interfaces = os.networkInterfaces();
	const ipAddress = [];
	for(var devName in interfaces){
	  var iface = interfaces[devName];
	  for(var i=0;i<iface.length;i++){
	        var alias = iface[i];
	        if(alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal){
	            ipAddress.push(alias.address);
	        }
	  }
	}
	return ipAddress;
}

const server = createServer((req, resp) => {

  const path = url.parse(req.url).pathname;
  console.log("Request for " + path + " received.");

  if (path === '/healthz') {
  	if (healthVar === true) {
	  	resp.writeHead(200, { 'Content-Type': 'text/plain' });
	  	resp.end('nodejs http server is health.');
  	} else {
	  	resp.writeHead(500, { 'Content-Type': 'text/plain' });
	  	resp.end('nodejs http server is unhealth.');
  	}
  } else if (path === '/shutdown') {
  	healthVar = false;
  	resp.writeHead(200, { 'Content-Type': 'text/plain' });
  	resp.end('nodejs http server is shutdown.');
  } else if (path === '/info') {
  	resp.writeHead(200, { 'Content-Type': 'text/plain' });
  	resp.end('nodejs http server info');
  } else if (path === '/interfaces') {
  	const interfaces = os.networkInterfaces();
  	resp.writeHead(200, { 'Content-Type': 'application/json' });
  	resp.write(JSON.stringify(interfaces));
  	resp.end();
  } else if (path === '/ip') {
  	const ipAddress = querHostIp();
  	resp.writeHead(200, { 'Content-Type': 'application/json' });
  	resp.write(JSON.stringify(ipAddress));
  	resp.end();
  } else {
	// the first param is status code it returns
	// and the second param is response header info
	resp.writeHead(200, { 'Content-Type': 'text/plain' });
	console.log('server is working...');
	// call end method to tell server that the request has been fulfilled
	resp.end('hello nodejs http server');
  }

});

server.listen(PORT, HOST, (error) => {
  if (error) {
    console.log('Something wrong: ', error);
    return;
  }

  console.log(`server is listening on http://${HOST}:${PORT} ...`, ' PID = ', process.pid);
});


/** 改造部分 关于进程结束相关信号可自行搜索查看*/
function close(signal) {
    console.log(`收到 ${signal} 信号开始处理`);
    server.close(() => {
        console.log(`服务停止 ${signal} 处理完毕`);
        process.exit(0);
    });
}

process.on('SIGTERM', close.bind(this, 'SIGTERM'));
process.on('SIGINT', close.bind(this, 'SIGINT'));
/** 改造部分 */
