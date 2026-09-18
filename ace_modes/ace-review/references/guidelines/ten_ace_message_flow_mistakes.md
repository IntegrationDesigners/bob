---
template_version: 1.0.0
last_updated: 2026-03-16
compatible_with: ACE Review v1.0.0+
status: stable
---
# Ten ACE Message Flow Mistakes You Can't Afford to Make!

**Author:** Philip Bareham  
**Published:** December 1, 2025  
**Source:** [IBM Community Blog](https://community.ibm.com/community/user/blogs/philip-bareham/2025/12/01/ten-ace-message-flow-mistakes-you-cant-afford-to-m)

---

## 1. Message Tree Copying

The message tree is a structured representation of a message as it passes through the flow. In ESQL and Java nodes, we can manipulate the message tree, but often it is copied without updates.

**Recommendation:** Avoid message tree copying if no updates to that message tree are made - copies are expensive.

**Action:** For an ESQL compute node use the `compute mode` property to control which message trees are used in the output. `Message` (meaning InputRoot) is the default. If you only update the LocalEnvironment in a compute node, set the compute mode to `LocalEnvironment` to avoid copying the unchanged Input message tree to the output.

---

## 2. Default Behaviours

ACE sets default values to help customers use the system quickly. However, these defaults may not be optimal for your specific use case.

**Example:** When an ESQL node is added to a message flow, the commented-out lines for `CALL CopyEntireMessage()` will be used, copying the whole message tree.

Avoid using `SET OutputRoot = InputRoot;` when you are not updating any fields:

```esql
CREATE COMPUTE MODULE TEST_MF_Compute
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        -- CALL CopyMessageHeaders();
        CALL CopyEntireMessage();  -- copies everything even if nothing changes
        RETURN TRUE;
    END;
END MODULE;
```

---

## 3. Adjacent Compute Nodes

Splitting logic into separate adjacent Compute or JavaCompute nodes leads to unnecessary message tree copies and reduced performance. If both `Check Input` and `Format Output` update the message tree, two message tree copies occur.

**Recommendation:** Combine adjacent compute nodes that update the message tree to reduce the number of copies.

---

## 4. Long Tree Paths

When ACE processes a message tree path (e.g., `InputRoot.XMLNSC.Message...`) it has to navigate through each step. This causes elongated processing time, especially at higher flow utilisation.

**Recommendation:** Avoid repeated long tree paths - use and declare a reference instead.

**Long tree path (bad):**
```esql
SET OutputRoot.XMLNSC.Message.CustomerDetail.Address.Locality = InputRoot.XMLNSC.UpdateMessage.HomeAddress.Locality;
SET OutputRoot.XMLNSC.Message.CustomerDetail.Address.Town = InputRoot.XMLNSC.UpdateMessage.HomeAddress.Town;
SET OutputRoot.XMLNSC.Message.CustomerDetail.Address.Postcode = InputRoot.XMLNSC.UpdateMessage.HomeAddress.Postcode;
```

**References used instead (good):**
```esql
DECLARE inAddressRef REFERENCE TO InputRoot.XMLNSC.UpdateMessage.HomeAddress;
DECLARE outAddressRef REFERENCE TO OutputRoot.XMLNSC.Message.CustomerDetail.Address;

SET outAddressRef.Locality = inAddressRef.Locality;
SET outAddressRef.Town = inAddressRef.Town;
SET outAddressRef.Postcode = inAddressRef.Postcode;
```

---

## 5. Message Flow Loops

A message flow with nodes that cause a flow loop can have severe impacts on the Integration Server, causing it to crash and run out of memory because the cyclic processing can loop with no exit condition.

**Example:** The `out1` terminal of a compute node being wired back to the input terminal of a preceding HTTP Request node creates an infinite loop.

**Recommendation:** Always check for unintentional cyclic wiring when designing flows with multiple output connections.

---

## 6. Message Parsing

Parsing a message is expensive, especially for large message trees. This is particularly true for large payloads, complex structures, and certain parser types.

**Recommendation:** Use the default `On demand` parsing setting in Input nodes wherever possible - this parses the message up to the point of the last reference required, reducing the amount of parsing ACE needs to do.

---

## 7. Static Message Tree Updates

If the message tree is not updated in a compute node, the tree will not be carried forward through the flow to the next node. This can cause issues with subsequent nodes that expect the message tree to be present.

**Recommendation:** Review the message tree updates to ensure they are being carried forward through the flow.

**Example:** Incorrect setting of Compute node mode. The default setting is `message` (InputRoot), meaning that changes made to OutputLocalEnvironment won't be carried forward unless the compute node mode includes `LocalEnvironment`.

---

## 8. Unconnected Output Terminals

Unconnected output terminals do not cause an error in the development environment. Some message flows may therefore silently throw messages away on edge cases, causing potential data loss that testing won't catch.

**Recommendation:** Review output terminals as part of the standard flow review process and include output terminal checks in static code analysis.

---

## 9. Multiple Output Terminal Connections Are Not Guaranteed to Execute in Any Order

When an output terminal has multiple connections, the order of execution is not guaranteed. This can impact processing correctness.

**Recommendation:** When multiple connections are required, use the `FlowOrder` node to set the correct processing path.

**Incorrect (order not guaranteed):**
```
Input → Node → Do this first → Output
             → Do this second →
```

**Correct (order guaranteed):**
```
Input → Node → FlowOrder → Do this first → Output
                         → Do this second →
```

---

## 10. Cardinality in Loops

If `CARDINALITY` is configured inside a loop, this is a performance problem with large arrays - the cost of evaluating CARDINALITY is compounded with every iteration.

**Recommendation:** Avoid using `CARDINALITY` inside a loop. Place the statement before the loop.

**Bad (CARDINALITY evaluated on every iteration):**
```esql
WHILE (I < CARDINALITY(InputRoot.XMLNSC.TestData.GroupItem.Array[]))
```

**Good (CARDINALITY evaluated once):**
```esql
SET totalItems = CARDINALITY(OutputRoot.XMLNSC.MyMessage.Array[]);

WHILE currentItem <= totalItems DO
    SET ...
    SET currentItem = currentItem + 1;
END WHILE;
```

---

## Summary

1. Avoid unnecessary message tree copying - use compute mode
2. Review and optimize default behaviors
3. Combine adjacent compute nodes
4. Use references instead of long tree paths
5. Prevent message flow loops
6. Use on-demand parsing
7. Ensure message tree updates are carried forward
8. Review and connect all output terminals
9. Use FlowOrder for multiple output connections
10. Calculate cardinality outside of loops
