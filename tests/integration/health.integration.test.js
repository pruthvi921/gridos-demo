// Integration tests for API health and system endpoints
const axios = require('axios');

const API_URL = process.env.API_URL || 'http://localhost:3000';

describe('System Health Integration Tests', () => {
  describe('Health Endpoints', () => {
    test('should return overall health status', async () => {
      const response = await axios.get(`${API_URL}/api/v1/health`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('status');
      expect(['healthy', 'degraded']).toContain(response.data.status);
    });

    test('should return database health status', async () => {
      const response = await axios.get(`${API_URL}/api/v1/health/db`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('status');
      expect(response.data.status).toBe('healthy');
    });

    test('should return readiness probe', async () => {
      const response = await axios.get(`${API_URL}/readiness`);

      expect(response.status).toBe(200);
    });

    test('should return liveness probe', async () => {
      const response = await axios.get(`${API_URL}/liveness`);

      expect(response.status).toBe(200);
    });
  });

  describe('Metrics Endpoints', () => {
    test('should expose Prometheus metrics', async () => {
      const response = await axios.get(`${API_URL}/metrics`);

      expect(response.status).toBe(200);
      expect(response.data).toContain('http_requests_total');
      expect(response.data).toContain('process_cpu_seconds_total');
    });
  });

  describe('API Info Endpoints', () => {
    test('should return API version', async () => {
      const response = await axios.get(`${API_URL}/api/v1/info`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('version');
      expect(response.data).toHaveProperty('environment');
    });
  });

  describe('Database Connectivity', () => {
    test('should successfully query database', async () => {
      const response = await axios.get(`${API_URL}/api/v1/health/db`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('connection_pool');
      expect(response.data.connection_pool).toHaveProperty('active');
      expect(response.data.connection_pool).toHaveProperty('idle');
    });
  });

  describe('Error Handling', () => {
    test('should return 404 for non-existent endpoint', async () => {
      try {
        await axios.get(`${API_URL}/api/v1/nonexistent`);
        fail('Should have thrown 404 error');
      } catch (error) {
        expect(error.response.status).toBe(404);
      }
    });

    test('should handle internal errors gracefully', async () => {
      try {
        await axios.get(`${API_URL}/api/v1/scada/data`, {
          params: { device_id: '' } // Invalid empty device ID
        });
        fail('Should have thrown validation error');
      } catch (error) {
        expect([400, 422]).toContain(error.response.status);
      }
    });
  });
});
