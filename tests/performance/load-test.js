// k6 Load Test Script for GridOS API
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const apiDuration = new Trend('api_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 10 },   // Stay at 10 users
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // 95% < 500ms, 99% < 1s
    'http_req_failed': ['rate<0.01'],  // Error rate < 1%
    'errors': ['rate<0.01'],
    'api_duration': ['p(95)<200'],  // API calls < 200ms (p95)
  },
};

const BASE_URL = __ENV.API_URL || 'http://localhost:8080';

export default function () {
  // Test 1: Health Check
  let healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);
  
  sleep(1);

  // Test 2: Get All Grid Nodes
  let nodesRes = http.get(`${BASE_URL}/api/gridnodes`, {
    headers: { 'Content-Type': 'application/json' },
  });
  
  const nodesSuccess = check(nodesRes, {
    'nodes status is 200': (r) => r.status === 200,
    'nodes response has data': (r) => {
      try {
        return JSON.parse(r.body).length > 0;
      } catch {
        return false;
      }
    },
  });
  
  if (!nodesSuccess) errorRate.add(1);
  apiDuration.add(nodesRes.timings.duration);
  
  sleep(2);

  // Test 3: Get Active Alarms
  let alarmsRes = http.get(`${BASE_URL}/api/alarms/active`, {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(alarmsRes, {
    'alarms status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(1);

  // Test 4: Get Grid Node by ID
  if (nodesRes.status === 200) {
    try {
      const nodes = JSON.parse(nodesRes.body);
      if (nodes.length > 0) {
        const nodeId = nodes[0].id;
        let nodeRes = http.get(`${BASE_URL}/api/gridnodes/${nodeId}`);
        
        check(nodeRes, {
          'node by id status is 200': (r) => r.status === 200,
        }) || errorRate.add(1);
      }
    } catch (e) {
      errorRate.add(1);
    }
  }
  
  sleep(2);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'performance-summary.json': JSON.stringify(data),
  };
}
