namespace GridOS.API.Models;

public class GridNode
{
    public int Id { get; set; }
    public required string NodeId { get; set; }
    public required string Name { get; set; }
    public string? Location { get; set; }
    public required string NodeType { get; set; } // Substation, Distribution, Transmission
    public double Capacity { get; set; } // MW
    public required string Status { get; set; } // Online, Offline, Maintenance, Alarm
    public DateTime InstallationDate { get; set; }
    public DateTime? LastMaintenanceDate { get; set; }
    
    // Navigation properties
    public ICollection<SensorReading> SensorReadings { get; set; } = new List<SensorReading>();
    public ICollection<Alarm> Alarms { get; set; } = new List<Alarm>();
    public ICollection<MaintenanceEvent> MaintenanceEvents { get; set; } = new List<MaintenanceEvent>();
}

public class SensorReading
{
    public int Id { get; set; }
    public int GridNodeId { get; set; }
    public DateTime Timestamp { get; set; }
    public double Voltage { get; set; } // kV
    public double Current { get; set; } // Amperes
    public double Power { get; set; } // MW
    public double Frequency { get; set; } // Hz
    public double Temperature { get; set; } // Celsius
    public double PowerFactor { get; set; }
    
    // Navigation property
    public GridNode? GridNode { get; set; }
}

public class Alarm
{
    public int Id { get; set; }
    public int GridNodeId { get; set; }
    public required string AlarmCode { get; set; }
    public required string Severity { get; set; } // Critical, High, Medium, Low
    public required string Message { get; set; }
    public required string Status { get; set; } // Active, Acknowledged, Resolved
    public DateTime RaisedAt { get; set; }
    public DateTime? AcknowledgedAt { get; set; }
    public string? AcknowledgedBy { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public string? Resolution { get; set; }
    
    // Navigation property
    public GridNode? GridNode { get; set; }
}

public class MaintenanceEvent
{
    public int Id { get; set; }
    public int GridNodeId { get; set; }
    public required string EventType { get; set; } // Scheduled, Emergency, Preventive
    public string? Description { get; set; }
    public required string Status { get; set; } // Planned, InProgress, Completed, Cancelled
    public DateTime ScheduledDate { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? PerformedBy { get; set; }
    public string? Notes { get; set; }
    
    // Navigation property
    public GridNode? GridNode { get; set; }
}
