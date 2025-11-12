using Microsoft.Extensions.Diagnostics.HealthChecks;
using GridOS.API.Data;

namespace GridOS.API.Services;

public class GridMonitoringHealthCheck : IHealthCheck
{
    private readonly GridOSDbContext _context;

    public GridMonitoringHealthCheck(GridOSDbContext context)
    {
        _context = context;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Check if we can query the database
            var nodeCount = await Task.Run(() => _context.GridNodes.Count(), cancellationToken);
            
            var data = new Dictionary<string, object>
            {
                { "grid_nodes_count", nodeCount },
                { "timestamp", DateTime.UtcNow }
            };

            return HealthCheckResult.Healthy("Grid monitoring system is operational", data);
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "Grid monitoring system is unavailable",
                ex);
        }
    }
}

public class MetricsCollectorService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<MetricsCollectorService> _logger;

    public MetricsCollectorService(
        IServiceProvider serviceProvider,
        ILogger<MetricsCollectorService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Metrics Collector Service starting");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<GridOSDbContext>();

                // Simulate collecting metrics from grid nodes
                var nodes = context.GridNodes.Where(n => n.Status == "Online").ToList();
                var random = new Random();

                foreach (var node in nodes)
                {
                    var reading = new Models.SensorReading
                    {
                        GridNodeId = node.Id,
                        Timestamp = DateTime.UtcNow,
                        Voltage = 230 + random.NextDouble() * 10,
                        Current = 100 + random.NextDouble() * 50,
                        Power = node.Capacity * (0.7 + random.NextDouble() * 0.3),
                        Frequency = 50 + random.NextDouble() * 0.1 - 0.05,
                        Temperature = 45 + random.NextDouble() * 20,
                        PowerFactor = 0.95 + random.NextDouble() * 0.05
                    };

                    context.SensorReadings.Add(reading);
                }

                await context.SaveChangesAsync(stoppingToken);
                _logger.LogDebug("Collected metrics for {Count} nodes", nodes.Count);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error collecting metrics");
            }

            // Collect every 30 seconds
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }

        _logger.LogInformation("Metrics Collector Service stopping");
    }
}
