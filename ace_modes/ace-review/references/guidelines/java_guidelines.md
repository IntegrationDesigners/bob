---
template_version: 1.0.0
last_updated: 2026-03-16
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Java Coding Guidelines

## General Principles

The same guidelines that apply to a good Java program also apply here.

### Memory and Garbage Collection Awareness

By creating your own Java code, you need to be aware of memory and garbage collection issues, since these make up the bulk of the performance issues. You can monitor memory and garbage collection via the JVM resource statistics. There is a Garbage Collection and Memory Visualizer that can be used to analyze the Java processes.

### Use Built-in Modules

**Don't use Java to replace any built-in modules or parsers.** The IBM provided methods/classes are designed to be highly performant.

---

## Single Instance

**Important:** Only one instance of a JavaCompute node is created and shared for all instances of the message flow.

Make sure that all custom written Java code is therefore **thread safe** and **re-entrant**.

- Avoid using instance variables for flow-specific data
- Use local variables within methods
- Synchronize access to shared resources
- Be careful with static variables

---

## Additional Processes

It is easy to spawn a new process from within the Java code, but **this is an expensive action in performance terms**. Avoid spawning new processes unless absolutely necessary.

---

## Tree References

Just like with ESQL, references help reduce costly message tree navigation. **Store fields as `MbElement` variables** in order to optimize message tree navigation.

### Example: Costly Navigation

```java
MbMessage newEnv = new MbMessage(inAssembly.getMessage());
newEnv.getRootElement().createElementAsFirstChild(MbElement.TYPE_NAME, "Destination", null);
newEnv.getRootElement().getFirstChild().createElementAsFirstChild(MbElement.TYPE_NAME, "MQDestinationList", null);
newEnv.getRootElement().getFirstChild().getFirstChild().createElementAsFirstChild(MbElement.TYPE_NAME, "DestinationData", null);
```

### Example: Optimized Navigation

```java
MbMessage newEnv2 = new MbMessage(inAssembly.getMessage());
MbElement destination = newEnv2.getRootElement().createElementAsFirstChild(MbElement.TYPE_NAME, "Destination", null);
MbElement mqDestinationList = destination.createElementAsFirstChild(MbElement.TYPE_NAME, "MQDestinationList", null);
mqDestinationList.createElementAsFirstChild(MbElement.TYPE_NAME, "DestinationData", null);
```

---

## String Concatenation

Just like with normal Java processes, concatenating strings with the `+` sign is very costly. **Use the `StringBuilder` class** for string concatenation.

### Example: Bad

```java
keyforCache = hostSystem + CommonFunctions.separator
    + sourceQueueValue + CommonFunctions.separator
    + smiKey + CommonFunctions.separator
    + newElement;
```

### Example: Good

```java
StringBuilder keyforCacheBuf = new StringBuilder();
keyforCacheBuf.append(hostSystem)
    .append(CommonFunctions.separator)
    .append(sourceQueueValue)
    .append(CommonFunctions.separator)
    .append(smiKey)
    .append(CommonFunctions.separator)
    .append(newElement);
String keyforCache = keyforCacheBuf.toString();
```

---

## BLOB Processing

Use `ByteArrayInputStream` and `ByteArrayOutputStream` for BLOB processing.

```java
MbElement blob = inputRoot.getLastChild().getLastChild();
ByteArrayInputStream inStream = new ByteArrayInputStream((byte[]) blob.getValue());
ByteArrayOutputStream outStream = new ByteArrayOutputStream();

byte[] readBuffer = new byte[2];
byte[] readSeperator = "#".getBytes();
int readSize;

while ((readSize = inStream.read(readBuffer)) > 0) {
    outStream.write(Arrays.copyOfRange(readBuffer, 0, readSize));
    outStream.write(readSeperator);
    readBuffer = new byte[2];
}
```

---

## Modifying the Proper Element

In a Java Compute Node, take care to modify the correct element. If you change the input element and use that in the output assembly, the changes can propagate unexpectedly to subsequent nodes in a flow order.

### Example: Problematic Code

```java
// This modifies the INPUT local environment - changes propagate downstream
MbMessage localEnv = inAssembly.getLocalEnvironment();
localEnv.getRootElement()
    .createElementAsFirstChild(MbElement.TYPE_NAME, "Variables", null)
    .createElementAsFirstChild(MbElement.TYPE_NAME_VALUE, "TEST2", "FLOW ORDER 2");

outAssembly = new MbMessageAssembly(inAssembly, localEnv, ...);
```

### Solution: Use Copy Constructor

```java
MbMessage localEnv = inAssembly.getLocalEnvironment();
MbMessage outEnv = new MbMessage(localEnv);  // create a COPY

outEnv.getRootElement()
    .createElementAsFirstChild(MbElement.TYPE_NAME, "Variables", null)
    .createElementAsFirstChild(MbElement.TYPE_NAME_VALUE, "TEST2", "FLOW ORDER 2");

outAssembly = new MbMessageAssembly(inAssembly, outEnv, ...);  // use the copy
```

**Always create copies of message elements when you need to modify them**, unless you explicitly want the changes to affect the input assembly.

---

## Exception Handling

ACE provides a specific exception class, `MbException`, for errors that originate from the ACE runtime and message flow infrastructure. Catching the generic `Exception` or `Throwable` instead of `MbException` loses critical ACE-specific error information.

### Rule

Always catch `MbException` explicitly when writing exception handlers in Java compute nodes. If you also need to handle non-ACE exceptions, add a separate `catch (Exception e)` block after the `MbException` block.

### Why This Matters

`MbException` carries structured error information including:
- Error number and text
- Insertion strings
- The full exception hierarchy from ACE internals

Catching `Exception` swallows this structure and reduces it to a plain message string, making troubleshooting significantly harder.

### Example

```java
// WRONG: catching generic Exception loses ACE error detail
try {
    // ... ACE operations
} catch (Exception e) {
    // e.getMessage() only gives a string - ACE context lost
    log.error("Error: " + e.getMessage());
}

// CORRECT: catch MbException first to preserve ACE error structure
try {
    // ... ACE operations
} catch (MbException e) {
    // Full ACE error information available
    int errorCode = e.getErrorCodeAsInt();
    String errorText = e.getMessage();
    // handle or rethrow
    throw e;
} catch (Exception e) {
    // Handle non-ACE exceptions separately
    throw new MbUserException(this, "evaluate()", "", "", e.getMessage(), null);
}
```

**Check:** Scan all catch blocks in Java compute nodes. Flag any that catch `Exception` or `Throwable` without a preceding `MbException` catch block.

---

## Output Tree Header Order

An `MbMessage` is serialized in **child order**, so an output message assembled in a Java compute node must be built headers-first:

1. `Properties` first.
2. Transport / protocol headers in wire order - MQ: `MQMD`, then `MQMDE` (if present), then `MQRFH2`; HTTP: the relevant header tree.
3. Body parser last.

The standard header-copy idiom walks the input children and stops before the last child (the body), appending each header with `addAsLastChild` so input order is preserved:

```java
private void copyMessageHeaders(MbMessage inMessage, MbMessage outMessage) throws MbException {
    MbElement outRoot = outMessage.getRootElement();
    MbElement header = inMessage.getRootElement().getFirstChild();
    while (header != null && header.getNextSibling() != null) {
        outRoot.addAsLastChild(header.copy());   // headers, in order, before the body
        header = header.getNextSibling();
    }
}
```

If headers are created before the body, or `Properties` is not first, the broker writes them to the wrong physical position or drops them, producing an unreadable message downstream.

**Check:** In nodes that build an output `MbMessage`, flag a header added with `addAsFirstChild` after the body has been built, a body parser tree created before the headers are copied, or `MQRFH2` added ahead of `MQMD`.

---

## Summary

1. **Be aware of memory and GC** - Monitor and optimize
2. **Ensure thread safety** - Single instance shared across flows
3. **Avoid spawning processes** - Expensive operation
4. **Use MbElement references** - Reduce tree navigation overhead
5. **Use StringBuilder** - Never concatenate with `+`
6. **Use ByteArray streams for BLOBs** - Efficient memory handling
7. **Copy message elements** - Avoid unintended side effects
8. **Don't replace built-in parsers** - IBM implementations are optimized
9. **Catch MbException explicitly** - Never swallow ACE errors with a generic Exception catch
10. **Build the output tree in header order** - `Properties`, then transport headers in wire order, then body last; copy headers before building the body
