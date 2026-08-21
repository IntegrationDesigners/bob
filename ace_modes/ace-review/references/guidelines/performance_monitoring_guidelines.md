---
template_version: 1.1.0
last_updated: 2026-07-02
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Performance and Monitoring Guidelines

## Performance Monitoring Tools

Built-in monitoring capabilities:

1. **Flow Statistics** - message flow performance metrics
2. **Resource Statistics** - JVM, threads, memory usage
3. **Activity Log** - detailed message flow execution
4. **Accounting and Statistics** - transaction-level data
5. **User Trace** - custom logging and debugging

```bash
# Enable flow statistics (node-managed servers)
# Note: the -e flag names the integration server; "execution group" is the historic IIB term
mqsichangeflowstats <integration_node> -s -e <integration_server> -f <flow_name> -c active

# View statistics
mqsireportflowstats <integration_node> -e <integration_server> -f <flow_name>
```

For independent (standalone) integration servers, enable statistics in `server.conf.yaml` (`Statistics` section) or via the web UI / admin REST API.

---

## Key Performance Indicators

| Metric | Description | Target |
|--------|-------------|--------|
| **Throughput** | Messages processed per second | Application-specific |
| **Response Time** | Average message processing time | < 1 second (typical) |
| **Error Rate** | Percentage of failed messages | < 1% |
| **CPU Usage** | Integration server CPU utilization | < 70% |
| **Memory Usage** | JVM heap utilization | < 80% |
| **Thread Pool** | Active vs. available threads | < 80% utilized |
| **Queue Depth** | Messages waiting in queues | Minimal backlog |

---

## Common Performance Bottlenecks

1. **Database operations** - slow queries, connection issues
2. **External service calls** - network latency, slow responses
3. **Message parsing** - complex or large messages
4. **Transformation logic** - inefficient ESQL/Java code
5. **Memory usage** - excessive copying, large messages

---

## Database Performance

Best practices:
1. Use connection pooling - reuse database connections
2. Optimize queries - use indexes, avoid full table scans
3. Batch operations - group multiple operations
4. Use prepared statements - parameterized PASSTHRU
5. Limit result sets - use WHERE clauses

```bash
# Configure database connection pool size (node-managed servers)
mqsichangeproperties <integration_node> -e <integration_server> \
    -o ComIbmJDBCProviders -n jdbcProviderXAPoolSize -v 20
```

---

## Memory Management

```bash
# View JVM memory statistics (node-managed servers)
mqsireportresourcestats <integration_node> -e <integration_server> -s JVM
```

Memory optimization techniques:
1. Avoid unnecessary message copies
2. Use streaming for large messages
3. Clear references when done
4. Limit message tree depth
5. Use appropriate compute modes

```esql
-- GOOD: Only copy what's needed
SET OutputRoot.MQMD = InputRoot.MQMD;
SET OutputRoot.XMLNSC.Response.Status = 'OK';
-- Don't do SET OutputRoot = InputRoot if you don't need everything
```

---

## Thread Pool Management

Additional instances (threads per flow) are a **deployment property**, not a statistics setting - `mqsichangeflowstats` only controls statistics collection and cannot change instances. Set them via:

```bash
# BAR override applied at build/deploy time
# (override file contains e.g. MyFlow#additionalInstances=4)
ibmint apply overrides overrides/prod.properties --bar-file App.bar
```

- Alternatively set the Additional instances property on the flow in the Toolkit / BAR editor before packaging, or configure defaults in `server.conf.yaml` for an independent integration server
- Don't over-provision - more threads does not equal better performance
- Monitor thread utilization - adjust based on actual usage
- Consider workload type - I/O-bound vs. CPU-bound
- Avoid thread starvation - balance across flows

---

## Caching Strategies

When to use caching:
- Frequently accessed reference data
- Slow-changing configuration data
- Expensive computation results

### Shared Variables (In-Memory Cache)

```esql
DECLARE customerCache SHARED ROW;

-- SHARED variables are accessed by multiple flow threads:
-- wrap the check-and-set in BEGIN ATOMIC to avoid a race condition
BEGIN ATOMIC
    IF NOT EXISTS(customerCache.{customerId}[]) THEN
        SET customerCache.{customerId} = fetchCustomerData(customerId);
    END IF;
END;

SET OutputRoot.Customer = customerCache.{customerId};
```

---

## Asynchronous Processing

Use async patterns when external applications are slow. This frees up processing threads and improves overall throughput.

```
Flow 1 (Request):
Input → Validate → MQOutput (Request Queue) → Immediate Response

Flow 2 (Processing):
MQInput (Request Queue) → Process → External Call → MQOutput (Response Queue)

Flow 3 (Response):
MQInput (Response Queue) → Format → Notify Client
```

---

## Large Message Handling

Strategies:
1. Use BLOB domain for binary data
2. Stream processing for very large files
3. Chunking - split into smaller pieces
4. Compression - reduce message size
5. Reference passing - store in file system, pass reference

---

## Monitoring and Alerting

1. **Real-time monitoring** - dashboard for live metrics
2. **Historical analysis** - trend analysis and capacity planning
3. **Alerting** - automated notifications for issues
4. **Log aggregation** - centralized logging (ELK, Splunk)

---

## Load Testing

Tools:
- JMeter - HTTP/SOAP load testing
- SoapUI - API testing
- MQ Performance Harness - MQ load testing

Checklist:
- Test with realistic message volumes and sizes
- Test concurrent users/connections
- Test sustained load (soak testing)
- Test peak load scenarios
- Monitor all KPIs during testing

---

## Performance Tuning Process

1. **Establish baseline** - measure current performance
2. **Identify bottlenecks** - use profiling and monitoring
3. **Make one change at a time** - measure impact
4. **Document changes** - track what works
5. **Re-test** - verify improvements
6. **Monitor in production** - ensure sustained performance

```bash
# JVM heap size (node-managed servers) - the value is in BYTES
# 1073741824 bytes = 1 GB
mqsichangeproperties <integration_node> -e <integration_server> \
    -o ComIbmJVMManager -n jvmMaxHeapSize -v 1073741824
```

For independent integration servers, set `jvmMaxHeapSize` under the `ResourceManagers.JVM` section of `server.conf.yaml` (also in bytes).

---

## Container Performance

```yaml
spec:
  pod:
    containers:
      runtime:
        resources:
          limits:
            cpu: "2"
            memory: 2Gi
          requests:
            cpu: "1"
            memory: 1Gi
  replicas: 3
```

Considerations:
1. Set appropriate CPU/memory limits
2. Scale out (horizontal) rather than up
3. Configure liveness and readiness probes
4. Optimize image size for startup time
5. Consider service mesh for network performance

---

## Logging Best Practices

- Production: ERROR and WARN only
- Development: INFO and DEBUG
- Performance testing: minimal logging
- Avoid logging in tight loops
- Use conditional logging controlled by environment variables

```esql
DECLARE debugEnabled BOOLEAN COALESCE(Environment.Variables.DebugMode, FALSE);
IF debugEnabled THEN
    CALL writeToLog('DEBUG', 'Processing customer: ' || customerId);
END IF;
```

---

## Performance Anti-Patterns

| Anti-Pattern | Impact | Solution |
|--------------|--------|----------|
| Synchronous calls to slow services | Thread blocking | Use async patterns |
| No connection pooling | Connection overhead | Enable pooling |
| Excessive logging | I/O overhead | Use appropriate log levels |
| Large message copies | Memory pressure | Use references, optimize compute mode |
| Unindexed database queries | Slow queries | Add appropriate indexes |
| No caching | Repeated expensive operations | Implement caching strategy |
| Sequential processing | Low throughput | Use parallel processing |
| No timeout configuration | Resource exhaustion | Set appropriate timeouts |

---

## Summary

1. Monitor KPIs continuously - throughput, response time, errors
2. Identify bottlenecks - database, external calls, parsing
3. Optimize database access - connection pooling, query optimization
4. Manage memory efficiently - avoid unnecessary copies
5. Configure thread pools based on workload
6. Implement caching for frequently accessed data
7. Use async patterns for slow or unreliable services
8. Optimize message handling - streaming for large messages
9. Perform load testing under realistic conditions
10. Tune systematically - measure, change, verify
11. Optimize containers - resource limits and scaling
12. Balance logging - performance vs. troubleshooting
