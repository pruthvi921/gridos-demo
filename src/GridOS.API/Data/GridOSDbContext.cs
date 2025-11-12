using Microsoft.EntityFrameworkCore;
using GridOS.API.Models;

namespace GridOS.API.Data;

public class GridOSDbContext : DbContext
{
    public GridOSDbContext(DbContextOptions<GridOSDbContext> options) : base(options)
    {
    }

    public DbSet<GridNode> GridNodes => Set<GridNode>();
    public DbSet<SensorReading> SensorReadings => Set<SensorReading>();
    public DbSet<Alarm> Alarms => Set<Alarm>();
    public DbSet<MaintenanceEvent> MaintenanceEvents => Set<MaintenanceEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // GridNode configuration
        modelBuilder.Entity<GridNode>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.NodeId).IsRequired().HasMaxLength(50);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Location).HasMaxLength(200);
            entity.Property(e => e.Status).IsRequired();
            entity.HasIndex(e => e.NodeId).IsUnique();
        });

        // SensorReading configuration
        modelBuilder.Entity<SensorReading>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Voltage).HasPrecision(10, 2);
            entity.Property(e => e.Current).HasPrecision(10, 2);
            entity.Property(e => e.Power).HasPrecision(12, 2);
            entity.Property(e => e.Frequency).HasPrecision(6, 2);
            entity.Property(e => e.Temperature).HasPrecision(5, 2);
            
            entity.HasOne(e => e.GridNode)
                .WithMany(n => n.SensorReadings)
                .HasForeignKey(e => e.GridNodeId)
                .OnDelete(DeleteBehavior.Cascade);
            
            entity.HasIndex(e => new { e.GridNodeId, e.Timestamp });
        });

        // Alarm configuration
        modelBuilder.Entity<Alarm>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.AlarmCode).IsRequired().HasMaxLength(20);
            entity.Property(e => e.Severity).IsRequired();
            entity.Property(e => e.Message).IsRequired().HasMaxLength(500);
            entity.Property(e => e.Status).IsRequired();
            
            entity.HasOne(e => e.GridNode)
                .WithMany(n => n.Alarms)
                .HasForeignKey(e => e.GridNodeId)
                .OnDelete(DeleteBehavior.Cascade);
            
            entity.HasIndex(e => new { e.Status, e.Severity });
        });

        // MaintenanceEvent configuration
        modelBuilder.Entity<MaintenanceEvent>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.EventType).IsRequired().HasMaxLength(50);
            entity.Property(e => e.Description).HasMaxLength(1000);
            entity.Property(e => e.Status).IsRequired();
            
            entity.HasOne(e => e.GridNode)
                .WithMany(n => n.MaintenanceEvents)
                .HasForeignKey(e => e.GridNodeId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Seed data
        SeedData(modelBuilder);
    }

    private void SeedData(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GridNode>().HasData(
            new GridNode
            {
                Id = 1,
                NodeId = "GRID-NODE-001",
                Name = "Oslo Central Substation",
                Location = "Oslo, Norway",
                NodeType = "Substation",
                Capacity = 150.5,
                Status = "Online",
                InstallationDate = new DateTime(2020, 1, 15)
            },
            new GridNode
            {
                Id = 2,
                NodeId = "GRID-NODE-002",
                Name = "Bergen Power Distribution",
                Location = "Bergen, Norway",
                NodeType = "Distribution",
                Capacity = 85.0,
                Status = "Online",
                InstallationDate = new DateTime(2019, 6, 20)
            }
        );
    }
}
