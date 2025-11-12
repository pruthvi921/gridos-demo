using GridOS.API.Data;
using GridOS.API.Models;
using Microsoft.EntityFrameworkCore;

namespace GridOS.API.Services;

public class GridMonitoringService : IGridMonitoringService
{
    private readonly GridOSDbContext _context;
    private readonly ILogger<GridMonitoringService> _logger;

    public GridMonitoringService(GridOSDbContext context, ILogger<GridMonitoringService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<IEnumerable<GridNode>> GetAllGridNodesAsync()
    {
        return await _context.GridNodes
            .Include(n => n.Alarms.Where(a => a.Status == "Active"))
            .ToListAsync();
    }

    public async Task<GridNode?> GetGridNodeByIdAsync(int id)
    {
        return await _context.GridNodes
            .Include(n => n.Alarms)
            .Include(n => n.MaintenanceEvents)
            .FirstOrDefaultAsync(n => n.Id == id);
    }

    public async Task<IEnumerable<SensorReading>> GetLatestReadingsAsync(int gridNodeId, int limit)
    {
        return await _context.SensorReadings
            .Where(r => r.GridNodeId == gridNodeId)
            .OrderByDescending(r => r.Timestamp)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<SensorReading> AddSensorReadingAsync(SensorReading reading)
    {
        _context.SensorReadings.Add(reading);
        await _context.SaveChangesAsync();
        
        // Check for alarm conditions
        await CheckAlarmConditions(reading);
        
        return reading;
    }

    public async Task<object> GetNodeStatisticsAsync(int gridNodeId, DateTime from, DateTime to)
    {
        var readings = await _context.SensorReadings
            .Where(r => r.GridNodeId == gridNodeId && r.Timestamp >= from && r.Timestamp <= to)
            .ToListAsync();

        if (!readings.Any())
        {
            return new { message = "No data available for the specified period" };
        }

        return new
        {
            Period = new { From = from, To = to },
            DataPoints = readings.Count,
            Voltage = new
            {
                Avg = readings.Average(r => r.Voltage),
                Min = readings.Min(r => r.Voltage),
                Max = readings.Max(r => r.Voltage)
            },
            Power = new
            {
                Avg = readings.Average(r => r.Power),
                Min = readings.Min(r => r.Power),
                Max = readings.Max(r => r.Power)
            },
            Temperature = new
            {
                Avg = readings.Average(r => r.Temperature),
                Min = readings.Min(r => r.Temperature),
                Max = readings.Max(r => r.Temperature)
            }
        };
    }

    private async Task CheckAlarmConditions(SensorReading reading)
    {
        // Example alarm conditions
        if (reading.Temperature > 80)
        {
            var alarm = new Alarm
            {
                GridNodeId = reading.GridNodeId,
                AlarmCode = "TEMP_HIGH",
                Severity = "High",
                Message = $"High temperature detected: {reading.Temperature}°C",
                Status = "Active",
                RaisedAt = DateTime.UtcNow
            };
            _context.Alarms.Add(alarm);
            await _context.SaveChangesAsync();
            _logger.LogWarning("High temperature alarm raised for node {NodeId}", reading.GridNodeId);
        }
    }
}

public class AlarmService : IAlarmService
{
    private readonly GridOSDbContext _context;

    public AlarmService(GridOSDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Alarm>> GetActiveAlarmsAsync()
    {
        return await _context.Alarms
            .Where(a => a.Status == "Active" || a.Status == "Acknowledged")
            .Include(a => a.GridNode)
            .OrderByDescending(a => a.RaisedAt)
            .ToListAsync();
    }

    public async Task<Alarm> CreateAlarmAsync(Alarm alarm)
    {
        alarm.RaisedAt = DateTime.UtcNow;
        alarm.Status = "Active";
        _context.Alarms.Add(alarm);
        await _context.SaveChangesAsync();
        return alarm;
    }

    public async Task<bool> AcknowledgeAlarmAsync(int alarmId, string acknowledgedBy)
    {
        var alarm = await _context.Alarms.FindAsync(alarmId);
        if (alarm == null) return false;

        alarm.Status = "Acknowledged";
        alarm.AcknowledgedAt = DateTime.UtcNow;
        alarm.AcknowledgedBy = acknowledgedBy;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ResolveAlarmAsync(int alarmId, string resolution)
    {
        var alarm = await _context.Alarms.FindAsync(alarmId);
        if (alarm == null) return false;

        alarm.Status = "Resolved";
        alarm.ResolvedAt = DateTime.UtcNow;
        alarm.Resolution = resolution;
        await _context.SaveChangesAsync();
        return true;
    }
}
