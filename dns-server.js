const dns = require('native-dns');
const server = dns.createServer();

// This is the IP of your laptop as seen by the devices on the hotspot
const HOTSPOT_IP = '192.168.137.1'; 

server.on('request', (request, response) => {
  const domain = request.question[0].name;
  console.log(`[DNS] Intercepting: ${domain} -> Redirecting to ${HOTSPOT_IP}`);

  response.answer.push(dns.A({
    name: domain,
    address: HOTSPOT_IP,
    ttl: 60, // Lower TTL is better for testing so changes propagate fast
  }));

  response.send();
});

server.on('error', (err) => {
  console.error('DNS Server Error:', err.message);
});

// Explicitly tell the server to listen on the Hotspot IP and Port 53
server.serve(53, HOTSPOT_IP); 

console.log(`DNS Server running at ${HOTSPOT_IP}:53`);
