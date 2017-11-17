const fs = require('fs');
var net = require('net');

var csDefine = {};

var tcp_server
function LoadConfigEnd() {
    tcp_server = net.createServer(connectASock).listen(csDefine.PORT, csDefine.HOST);
    console.log('Server listening on ' + csDefine.HOST +':'+ csDefine.PORT);

    udp_server.bind(csDefine.PORT, csDefine.HOST);
}

fs.readFile('../csShare/csDefine.js', 'utf-8', function(err, data){
    if (err) {
    } else {
        csDefine = JSON.parse(data);
        // console.log(csDefine);
        LoadConfigEnd()
    }
});

class Player {
  constructor(id, x, y, name) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.id = id;
    this.name = name;
    this.udp_h = null;
  }

  setUdpHandle(udp_h) {
    this.udp_h = udp_h;
  }

  getUdpHandle(udp_h) {
    return this.udp_h;
  }

  getPos() {
    return {x:this.x, y:this.y};
  }

  getId() {
    return this.id;
  }

  getName() {
    return this.name;
  }

  doMove(p) {
    this.x += p.x;
    this.y += p.y;
  }
}

class World {
  constructor(w, h) {
    this.w = w;
    this.h = h;
  }

  getCenterPos() {
    return {x:this.w / 2, y:this.h / 2};
  }

  getWorldSize() {
    return {width:this.w, height:this.h};
  }
}

var world = new World(960, 640);
var sock_data = {};
var sock_list = [];

function getPlayer(sock) {
    var index = sock_list.indexOf(sock);
    if (sock_list[index])
        return sock_list[index].player;
}

function sockWrite(sock, json_data, tail_mark) {
    tail_mark = tail_mark || csDefine.procotolTailMark;
    if (sock && sock.write && json_data) {
        sock.write(JSON.stringify(json_data) + tail_mark)
    }
}

function writeToAllSock(data) {
    var s
    for (const k in sock_list) {
        s = sock_list[k];
        sockWrite(s, data);
    }
}

function worldCreatePlayer(sock, player) {
    sockWrite(sock, {
        cmd:'sc_create_player_return',
        param:{
            pos:player.getPos(),
            name:player.getName(),
            playerId:player.getId()
        }
    });

    var data = {
        cmd:'sc_world_vis_player',
        param:{
            pos:player.getPos(),
            name:player.getName(),
            playerId:player.getId()
        }
    }

    for (const k in sock_list) {
        var s = sock_list[k];
        var p = sock_list[k].player;

        // console.log("-----" + p.getId() + ' ---- ' + sock.player.getId() + (sock.player.getId() != p.getId()))
        if(s != sock) {
            sockWrite(s, data);
        }

        if (p && p.getId && sock.player.getId() != p.getId()) {

            sockWrite(sock, {
                cmd:'sc_world_vis_player',
                param:{
                    pos:p.getPos(),
                    name:p.getName(),
                    playerId:p.getId()
                }
            });
        }
    }
}

var player_index = 0;
function handleCreatePlayer(sock, param) {
    if (sock_data[sock] && !sock_data[sock].player) {
        player_index += 1;
        var pos = world.getCenterPos();
        var player = new Player(player_index, pos.x, pos.y, param.name);
        sock_data[sock].player = player;
        sock_data[sock].sock = sock;
        sock.player = player;
        worldCreatePlayer(sock, player);
    }
}

function handlePlayerMove(sock, param) {
    var player = getPlayer(sock);
    if (!player && param && param.movePos)
        return;

    player.doMove(param.movePos);

    writeToAllSock({
        cmd:'sc_player_move',
        param:{
            pos:player.getPos(),
            playerId:player.getId()
        }
    });
}

function handleSockClose(sock, data) {
    console.log('CLOSED: ' + sock.remoteAddress + ' ' + sock.remotePort);
    var player_id = sock.player ? sock.player.getId() : -1;
    sock_data[sock] = null;
    var idx = sock_list.indexOf(sock);
    sock_list.splice(idx, 1);

    if (player_id > 0) 
        writeToAllSock({
            cmd:'cs_one_player_close',
            param:{
                playerId:player_id
            }
        });
}

function handleClientData(sock, data) {
    // console.log(data.toString())
    var datas = data.toString().split(csDefine.procotolTailMark)
    console.log(datas)
    for (var i = datas.length - 1; i >= 0; i--) {
        if (datas[i].length > 0) {
            var json_data = JSON.parse(datas[i]);
            if (json_data) {
                switch (json_data.cmd) {
                    case 'cs_create_player' :
                        handleCreatePlayer(sock, json_data.param)
                        break;
                    case 'cs_player_move' :
                        handlePlayerMove(sock, json_data.param)
                        break;
                    default:
                        break;
                }
            }
        }
    }
}

function startASock(sock) {
    console.log('CONNECTED: ' + sock.remoteAddress + ':' + sock.remotePort);

    sock_data[sock] = {};
    sock_list.push(sock);
    sockWrite(sock, {cmd:'world_size', param:world.getWorldSize()});
}

function connectASock(sock) {
    startASock(sock);

    sock.on('data', function(data) {
        handleClientData(sock, data);
    });

    sock.on('close', function(data) {
       handleSockClose(sock, data);
    });

    sock.on('error', function(e) {
        if (e.code === 'EADDRINUSE') {
            console.log('Address in use, retrying...');
        }

        setTimeout(() => {
            tcp_server.close();
            tcp_server.listen(csDefine.PORT, csDefine.HOST);
        }, 1000);

    });
}


// UDP ---------------------------------------------------------------

const dgram = require('dgram');
const udp_server = dgram.createSocket('udp4');

var udp_info_list = {};

function udpWrite(udp_h, json_data, tail_mark) {
    tail_mark = tail_mark || csDefine.procotolTailMark;
    if (udp_h && udp_h.rinfo && json_data) {
        var msg = JSON.stringify(json_data) + tail_mark;
        udp_server.send(msg, udp_h.rinfo.port, udp_h.rinfo.address);
    }
}

function writeToAllUdpH(data) {
    for (const k in udp_info_list) {
        udpWrite(udp_info_list[k], data);
    }
}

function getUdpHandleId(rinfo) {
    return rinfo.address + rinfo.port;
}

function getkUdpHandle(rinfo) {
    var udp_h = getUdpHandleId(rinfo)
    if (!udp_info_list[udp_h]) {
        udp_info_list[udp_h] = {rinfo:rinfo};
    }

    return udp_info_list[udp_h];
}

function handleUdpPlayerMove(udp_h, param) {
    var player = udp_h.player;
    if (!player && param && param.movePos)
        return;

    player.doMove(param.movePos);

    writeToAllUdpH({
        cmd:'sc_player_move',
        param:{
            pos:player.getPos(),
            playerId:player.getId()
        }
    });
}

function worldCreateUdpPlayer(player) {
    var udp_h = player.getUdpHandle();
    console.log(worldCreateUdpPlayer);
    udpWrite(udp_h, {
        cmd:'sc_create_player_return',
        param:{
            pos:player.getPos(),
            name:player.getName(),
            playerId:player.getId()
        }
    });

    var data = {
        cmd:'sc_world_vis_player',
        param:{
            pos:player.getPos(),
            name:player.getName(),
            playerId:player.getId()
        }
    }

    for (const k in udp_info_list) {
        var h = udp_info_list[k];
        var p = h.player;

        // console.log("-----" + p.getId() + ' ---- ' + sock.player.getId() + (sock.player.getId() != p.getId()))
        if(h != udp_h) {
            udpWrite(h, data);
        }

        if (p && p.getId && udp_h.player.getId() != p.getId()) {
            udpWrite(udp_h, {
                cmd:'sc_world_vis_player',
                param:{
                    pos:p.getPos(),
                    name:p.getName(),
                    playerId:p.getId()
                }
            });
        }
    }
}

var player_index = 0;
function handleUdpCreatePlayer(udpH, param) {
    if (!udpH.player) {
        player_index += 1;
        var pos = world.getCenterPos();
        var player = new Player(player_index, pos.x, pos.y, param.name);
        player.setUdpHandle(udpH);
        udpH.player = player;
        worldCreateUdpPlayer(player);
    }
}

function handleUdpClientData(udpH, data) {
    // console.log(data.toString())
    var datas = data.toString().split(csDefine.procotolTailMark)
    console.log(datas)
    for (var i = datas.length - 1; i >= 0; i--) {
        if (datas[i].length > 0) {
            var json_data = JSON.parse(datas[i]);
            if (json_data) {
                switch (json_data.cmd) {
                    case 'cs_create_player' :
                        handleUdpCreatePlayer(udpH, json_data.param)
                        break;
                    case 'cs_player_move' :
                        handleUdpPlayerMove(udpH, json_data.param)
                        break;
                    default:
                        break;
                }
            }
        }
    }
}

udp_server.on('error', (err) => {
    console.log(`服务器异常：\n${err.stack}`);
    udp_server.close();
});

udp_server.on('message', (msg, rinfo) => {
    console.log(`服务器收到：${msg} 来自 ${rinfo.address}:${rinfo.port}`);
    var udpH = getkUdpHandle(rinfo);
    handleUdpClientData(udpH, msg);
});

udp_server.on('listening', () => {
    const address = udp_server.address();
    console.log(`服务器监听 ${address.address}:${address.port}`);
});
