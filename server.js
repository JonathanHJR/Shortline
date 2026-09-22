const app = require('./app');
const PORT = process.env.PORT || 8080;

const server = app.listen(PORT, () => console.log(`shortline listening on ${PORT}`));

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('closed remaining connections');
    process.exit(0);
  });
});
