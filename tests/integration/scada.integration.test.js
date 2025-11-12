// Integration tests for SCADA endpoints
const axios = require('axios');

const API_URL = process.env.API_URL || 'http://localhost:3000';
const TEST_ENV = process.env.TEST_ENV || 'dev';

describe('SCADA Integration Tests', () => {
  let testDeviceId;

  beforeAll(() => {
    testDeviceId = `test-device-${Date.now()}`;
  });

  describe('Data Ingestion', () => {
    test('should ingest SCADA data successfully', async () => {
      const payload = {
        device_id: testDeviceId,
        voltage: 230,
        current: 10,
        power_factor: 0.95,
        timestamp: new Date().toISOString()
      };

      const response = await axios.post(`${API_URL}/api/v1/scada/data`, payload);
      
      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty('id');
      expect(response.data.device_id).toBe(testDeviceId);
    });

    test('should reject invalid SCADA data', async () => {
      const payload = {
        device_id: testDeviceId,
        voltage: -1, // Invalid voltage
        current: 10
      };

      try {
        await axios.post(`${API_URL}/api/v1/scada/data`, payload);
        fail('Should have thrown validation error');
      } catch (error) {
        expect(error.response.status).toBe(400);
      }
    });
  });

  describe('Data Retrieval', () => {
    test('should retrieve SCADA data by device ID', async () => {
      const response = await axios.get(`${API_URL}/api/v1/scada/data`, {
        params: { device_id: testDeviceId }
      });

      expect(response.status).toBe(200);
      expect(Array.isArray(response.data)).toBe(true);
      expect(response.data.length).toBeGreaterThan(0);
    });

    test('should retrieve latest SCADA status', async () => {
      const response = await axios.get(`${API_URL}/api/v1/scada/status`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('devices_online');
      expect(response.data).toHaveProperty('total_devices');
    });
  });

  describe('Time Series Data', () => {
    test('should retrieve time series data with time range', async () => {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - 3600000); // 1 hour ago

      const response = await axios.get(`${API_URL}/api/v1/scada/timeseries`, {
        params: {
          device_id: testDeviceId,
          start: startTime.toISOString(),
          end: endTime.toISOString()
        }
      });

      expect(response.status).toBe(200);
      expect(Array.isArray(response.data)).toBe(true);
    });
  });

  describe('Alerts and Alarms', () => {
    test('should retrieve active alarms', async () => {
      const response = await axios.get(`${API_URL}/api/v1/scada/alarms`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('active_alarms');
      expect(Array.isArray(response.data.active_alarms)).toBe(true);
    });

    test('should create alarm threshold', async () => {
      const payload = {
        device_id: testDeviceId,
        parameter: 'voltage',
        threshold: 250,
        condition: 'greater_than'
      };

      const response = await axios.post(`${API_URL}/api/v1/scada/alarms/threshold`, payload);

      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty('threshold_id');
    });
  });
});
