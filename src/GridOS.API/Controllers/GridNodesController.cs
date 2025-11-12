using Microsoft.AspNetCore.Mvc;
using GridOS.API.Services;
using GridOS.API.Models;

namespace GridOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class GridNodesController : ControllerBase
{
    private readonly IGridMonitoringService _monitoringService;
    private readonly ILogger<GridNodesController> _logger;

    public GridNodesController(
        IGridMonitoringService monitoringService,
        ILogger<GridNodesController> logger)
    {
        _monitoringService = monitoringService;
        _logger = logger;
    }

    /// <summary>
    /// Get all grid nodes
    /// </summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<GridNode>>> GetAllNodes()
    {
        _logger.LogInformation("Retrieving all grid nodes");
        var nodes = await _monitoringService.GetAllGridNodesAsync();
        return Ok(nodes);
    }

    /// <summary>
    /// Get grid node by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<GridNode>> GetNode(int id)
    {
        _logger.LogInformation("Retrieving grid node {NodeId}", id);
        var node = await _monitoringService.GetGridNodeByIdAsync(id);
        
        if (node == null)
        {
            _logger.LogWarning("Grid node {NodeId} not found", id);
            return NotFound();
        }
        
        return Ok(node);
    }

    /// <summary>
    /// Get latest sensor readings for a grid node
    /// </summary>
    [HttpGet("{id}/readings")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IEnumerable<SensorReading>>> GetReadings(int id, [FromQuery] int limit = 100)
    {
        _logger.LogInformation("Retrieving sensor readings for grid node {NodeId}", id);
        var readings = await _monitoringService.GetLatestReadingsAsync(id, limit);
        return Ok(readings);
    }

    /// <summary>
    /// Add a new sensor reading
    /// </summary>
    [HttpPost("{id}/readings")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SensorReading>> AddReading(int id, [FromBody] SensorReading reading)
    {
        reading.GridNodeId = id;
        reading.Timestamp = DateTime.UtcNow;
        
        var created = await _monitoringService.AddSensorReadingAsync(reading);
        _logger.LogInformation("Added sensor reading for grid node {NodeId}", id);
        
        return CreatedAtAction(nameof(GetReadings), new { id }, created);
    }

    /// <summary>
    /// Get grid node statistics
    /// </summary>
    [HttpGet("{id}/stats")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<object>> GetStatistics(int id, [FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        from ??= DateTime.UtcNow.AddHours(-24);
        to ??= DateTime.UtcNow;
        
        var stats = await _monitoringService.GetNodeStatisticsAsync(id, from.Value, to.Value);
        return Ok(stats);
    }
}

[ApiController]
[Route("api/[controller]")]
public class AlarmsController : ControllerBase
{
    private readonly IAlarmService _alarmService;
    private readonly ILogger<AlarmsController> _logger;

    public AlarmsController(IAlarmService alarmService, ILogger<AlarmsController> logger)
    {
        _alarmService = alarmService;
        _logger = logger;
    }

    /// <summary>
    /// Get all active alarms
    /// </summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Alarm>>> GetActiveAlarms()
    {
        var alarms = await _alarmService.GetActiveAlarmsAsync();
        return Ok(alarms);
    }

    /// <summary>
    /// Acknowledge an alarm
    /// </summary>
    [HttpPost("{id}/acknowledge")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> AcknowledgeAlarm(int id, [FromBody] string acknowledgedBy)
    {
        var result = await _alarmService.AcknowledgeAlarmAsync(id, acknowledgedBy);
        if (!result)
        {
            return NotFound();
        }
        
        _logger.LogInformation("Alarm {AlarmId} acknowledged by {User}", id, acknowledgedBy);
        return Ok();
    }

    /// <summary>
    /// Resolve an alarm
    /// </summary>
    [HttpPost("{id}/resolve")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> ResolveAlarm(int id, [FromBody] string resolution)
    {
        var result = await _alarmService.ResolveAlarmAsync(id, resolution);
        if (!result)
        {
            return NotFound();
        }
        
        _logger.LogInformation("Alarm {AlarmId} resolved", id);
        return Ok();
    }
}
