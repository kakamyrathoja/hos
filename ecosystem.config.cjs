module.exports = {
  apps: [{
    name: 'hossarpay-backend',
    script: 'npx tsx src/index.ts',
    cwd: '/var/www/hossarpay',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
