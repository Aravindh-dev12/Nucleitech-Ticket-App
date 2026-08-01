const { WebSocketServer } = require('ws');

const port = Number(process.env.PORT || 5001);
const server = new WebSocketServer({ port });

function payload(siteId) {
  const now = Date.now();
  const wave = Math.sin(now / 12000);
  const activePower = Math.max(0, 760 + wave * 120);

  return {
    siteId,
    timestamp: new Date().toISOString(),
    data: {
      plant_status: 'Online',
      active_power: Number(activePower.toFixed(2)),
      today_energy: Number((3812 + (now % 100000) / 100000).toFixed(2)),
      total_energy: Number((19500211 + now / 100000000).toFixed(2)),
      irradiance: Number((720 + wave * 80).toFixed(2)),
      grid_voltage: Number((415 + wave * 1.8).toFixed(2)),
      grid_frequency: Number((50 + wave * 0.03).toFixed(2)),
      performance_ratio: Number((78 + wave * 1.5).toFixed(2)),
      inverters: Array.from({ length: 4 }, (_, index) => ({
        name: `Inverter ${String(index + 1).padStart(2, '0')}`,
        status: index === 3 && wave < -0.8 ? 'Warning' : 'Online',
        active_power: Number((activePower / 4 + index * 1.2).toFixed(2)),
        dc_voltage: Number((820 + wave * 7 + index).toFixed(2)),
        ac_voltage: Number((415 + wave + index * 0.1).toFixed(2)),
        temperature: Number((41 + index + wave * 2).toFixed(2)),
      })),
      vcbs: [
        {
          name: 'Main VCB',
          status: 'Closed',
          voltage: 11000,
          current: Number((43 + wave * 4).toFixed(2)),
          trip_status: 'Healthy',
        },
      ],
    },
  };
}

server.on('connection', (socket) => {
  let siteId = 'unknown';
  let timer;

  socket.on('message', (message) => {
    try {
      const request = JSON.parse(message.toString());
      siteId = request.siteId || request.site_id || request.site || request.plant || siteId;
    } catch (_) {}

    clearInterval(timer);
    socket.send(JSON.stringify(payload(siteId)));
    timer = setInterval(() => {
      if (socket.readyState === socket.OPEN) {
        socket.send(JSON.stringify(payload(siteId)));
      }
    }, 3000);
  });

  socket.on('close', () => clearInterval(timer));
});

console.log(`NUCLEI TECH mock SCADA WebSocket running on ws://localhost:${port}`);
