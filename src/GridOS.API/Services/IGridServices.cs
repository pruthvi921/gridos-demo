using GridOS.API.Models;

namespace GridOS.API.Services;

public interface IGridMonitoringService
{
    Task<IEnumerable<GridNode>> GetAllGridNodesAsync();
    Task<GridNode?> GetGridNodeByIdAsync(int id);
    Task<IEnumerable<SensorReading>> GetLatestReadingsAsync(int gridNodeId, int limit);
    Task<SensorReading> AddSensorReadingAsync(SensorReading reading);
    Task<object> GetNodeStatisticsAsync(int gridNodeId, DateTime from, DateTime to);
}

public interface IAlarmService
{
    Task<IEnumerable<Alarm>> GetActiveAlarmsAsync();
    Task<Alarm> CreateAlarmAsync(Alarm alarm);
    Task<bool> AcknowledgeAlarmAsync(int alarmId, string acknowledgedBy);
    Task<bool> ResolveAlarmAsync(int alarmId, string resolution);
}
