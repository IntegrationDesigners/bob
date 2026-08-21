---
template_version: 0.1.0
last_updated: 2026-06-10
compatible_with: ACE Flow Builder v0.2.0+
status: stable
---

# ACE Java Compute Project

**When to read:** any time the flow uses one or more `ComIbmJavaCompute` nodes.

In ACE, Java code for a Java Compute node does **not** live in the application project. It lives in a **sibling Java project** that the application references via its `.project` `<projects>` block. `ibmint package --input-path <parent-dir>` discovers both projects in one pass, compiles the Java, and embeds the resulting `.jar` in the BAR.

This file documents the project layout, the `.project` / `.classpath` templates, and the wiring required on both sides.

---

## When to use Java (vs ESQL)

Prefer ESQL by default - it's lighter, stays inside the message tree, and the runtime has a parser/optimiser tuned for it. Reach for Java only when ESQL genuinely doesn't cover the case:

- **Library access** that ESQL can't reach: `com.ibm.mq.constants.MQConstants.lookup()` for MQ code→name translation, crypto (`javax.crypto.*`), regex with backreferences, third-party SDKs, JSON-schema validation, etc.
- **Heavy string / collection processing** - e.g. multi-pass parsing, nested loops over PCF groups - that gets clunky in ESQL.
- **Existing reusable Java code** the user has already written and wants to call from the flow.

Don't reach for Java for simple field mapping or shape changes - ESQL is shorter and easier to maintain.

---

## Project layout

The Java code lives in a sibling project next to the application:

```
<workspace>/
├── MyApp/                       (application project)
│   ├── .project                 ← lists MyAppJava under <projects>
│   ├── application.descriptor
│   ├── shared/HandleEvent.subflow
│   ├── shared/HandleEvent_Compute.esql
│   └── ...other .msgflow / .esql files
└── MyAppJava/                   (Java compute project)
    ├── .project
    ├── .classpath
    └── shared/                  (package = folder)
        └── HandleEvent_JavaCompute.java
```

Naming convention: `<AppName>Java` for the sibling project. The Java package path (`shared/HandleEvent_JavaCompute.java`) becomes the package declaration in the source (`package shared;`) and the value passed to the msgflow node's `javaClass` attribute (`javaClass="shared.HandleEvent_JavaCompute"`).

---

## `MyAppJava/.project` - verbatim template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
	<name>MyAppJava</name>
	<comment></comment>
	<projects>
	</projects>
	<buildSpec>
		<buildCommand>
			<name>org.eclipse.jdt.core.javabuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.jcn.jcnbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.bar.ext.barbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
	</buildSpec>
	<natures>
		<nature>org.eclipse.jdt.core.javanature</nature>
		<nature>com.ibm.etools.mft.jcn.jcnnature</nature>
		<nature>com.ibm.etools.mft.bar.ext.barnature</nature>
	</natures>
</projectDescription>
```

The three required natures (`javanature` + `jcnnature` + `barnature`) and the three buildCommand entries (`javabuilder` + `jcnbuilder` + `barbuilder`) together tell ACE this is a Java Compute Node project. Without `jcnnature`, the project compiles but the resulting `.jar` is not packaged into the BAR.

---

## `MyAppJava/.classpath` - verbatim template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<classpath>
	<classpathentry kind="src" path=""/>
	<classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/>
	<classpathentry kind="var" path="JCN_HOME/javacompute.jar"/>
	<classpathentry kind="var" path="JCN_HOME/jplugin2.jar"/>
	<classpathentry kind="var" path="COMMON_CLASSES_HOME/IntegrationAPI.jar"/>
	<classpathentry kind="con" path="com.ibm.etools.mft.uri.classpath.MBProjectReference"/>
	<classpathentry kind="output" path=""/>
</classpath>
```

The five non-optional entries are:

| Entry | Role |
|---|---|
| `kind="src" path=""` | The project root is the source root. Package = folder. |
| `JRE_CONTAINER` | The JDK to compile against. Match `--java-version` passed to `ibmint package`. |
| `JCN_HOME/javacompute.jar` | The Java Compute Node API (`MbJavaComputeNode`, `MbMessage`, `MbElement`, `MbOutputTerminal`). |
| `JCN_HOME/jplugin2.jar` | Plugin bridge - needed for the JCN runtime to load the class. |
| `COMMON_CLASSES_HOME/IntegrationAPI.jar` | The broader Integration API (`MbJSON.ARRAY`, `MbJSON.DATA_ELEMENT_NAME`, etc.). |
| `MBProjectReference` | Classpath container that pulls in classpaths of any referenced ACE library / shared-library projects. |
| `output` | Compiled `.class` output goes alongside the source. |

### Adding third-party jars

For a jar that lives on disk:
```xml
<classpathentry kind="lib" path="C:/Program Files/IBM/ACE/13.0.7.0/server/MQ/lib/com.ibm.mq.allclient.jar"/>
```

Common cases:

| Need | Jar | Path |
|---|---|---|
| `com.ibm.mq.constants.MQConstants.lookup` (MQCMD_*, MQCA_*, reason codes) | `com.ibm.mq.allclient.jar` | `<ACE_INSTALL>/server/MQ/lib/com.ibm.mq.allclient.jar` (bundled with every ACE install) |
| MQ Java client classes (`MQMessage`, `MQQueue`) | `com.ibm.mq.allclient.jar` | same path |
| Jackson JSON | `jackson-*.jar` | user-supplied location |

Don't reference the user's standalone MQ install (`C:/Program Files/IBM/MQ/java/lib/com.ibm.mq.jmqi.jar`) by default - many ACE-only installations don't have standalone MQ. The ACE-bundled `server/MQ/lib/com.ibm.mq.allclient.jar` is always present.

---

## Application-side wiring (in `MyApp/.project`)

The application's `.project` must reference the sibling Java project under `<projects>`:

```xml
<projectDescription>
	<name>MyApp</name>
	<comment></comment>
	<projects>
		<project>MyAppJava</project>
	</projects>
	<buildSpec>
		<!-- ...the standard 21 application-project buildCommand entries... -->
	</buildSpec>
	<natures>
		<nature>com.ibm.etools.msgbroker.tooling.applicationNature</nature>
		<nature>com.ibm.etools.msgbroker.tooling.messageBrokerProjectNature</nature>
		<nature>com.ibm.etools.mft.bar.ext.barnature</nature>
	</natures>
</projectDescription>
```

Without the `<projects><project>MyAppJava</project></projects>` block, ACE Toolkit and `ibmint package` won't link the Java project to the application - the Java class won't be found at deploy time and the flow will fail with `MbClassNotFoundException`.

---

## Java source skeleton

Place the source at `MyAppJava/<package-as-folders>/<Class>.java`. The class must extend `MbJavaComputeNode` and override `evaluate(MbMessageAssembly inAssembly)`.

```java
package shared;

import com.ibm.broker.javacompute.MbJavaComputeNode;
import com.ibm.broker.plugin.MbElement;
import com.ibm.broker.plugin.MbException;
import com.ibm.broker.plugin.MbJSON;
import com.ibm.broker.plugin.MbMessage;
import com.ibm.broker.plugin.MbMessageAssembly;
import com.ibm.broker.plugin.MbOutputTerminal;
import com.ibm.broker.plugin.MbUserException;

public class HandleEvent_JavaCompute extends MbJavaComputeNode {

	public void evaluate(MbMessageAssembly inAssembly) throws MbException {
		MbOutputTerminal out = getOutputTerminal("out");
		MbMessage inMessage = inAssembly.getMessage();
		MbMessageAssembly outAssembly = null;
		try {
			MbMessage outMessage = new MbMessage();
			copyMessageHeaders(inMessage, outMessage);

			// ...build outMessage tree here...

			outAssembly = new MbMessageAssembly(inAssembly, outMessage);
		} catch (MbException e) {
			throw e;
		} catch (RuntimeException e) {
			throw e;
		} catch (Exception e) {
			throw new MbUserException(this, "evaluate()", "", "", e.toString(), null);
		}
		out.propagate(outAssembly);
	}

	private void copyMessageHeaders(MbMessage inMessage, MbMessage outMessage) throws MbException {
		MbElement outRoot = outMessage.getRootElement();
		MbElement header = inMessage.getRootElement().getFirstChild();
		while (header != null && header.getNextSibling() != null) {
			outRoot.addAsLastChild(header.copy());
			header = header.getNextSibling();
		}
	}
}
```

The triple-catch is the standard ACE idiom: rethrow `MbException` and `RuntimeException` so the broker handles them, wrap anything else in `MbUserException`.

`copyMessageHeaders` walks the input children and stops before the last child (the body), copying every header with `addAsLastChild` so the input order is preserved. Header order matters: `OutputRoot` serializes in child order, so headers must be copied before the body parser tree is built and the body added last. See `validated_rules.md` rule 13.

---

## `.msgflow` wiring

The `ComIbmJavaCompute` node in the `.msgflow` references the Java class by fully-qualified name:

```xml
<nodes xmi:type="ComIbmJavaCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_3"
    location="101,20" javaClass="shared.HandleEvent_JavaCompute">
  <translation xmi:type="utility:ConstantString" string="Java Compute"/>
</nodes>
```

The value of `javaClass` must match the Java source's `package` + class name exactly. Mismatch is silent at package time but fails at runtime with `MbClassNotFoundException`.

The XML namespace declaration on the `.msgflow` root needs `xmlns:ComIbmJavaCompute.msgnode="ComIbmJavaCompute.msgnode"` - same pattern as every other ACE node type.

---

## Building with `ibmint package`

`ibmint package` discovers both projects automatically when pointed at the parent directory:

```bash
ibmint package \
    --input-path <workspace> \
    --output-bar-file <name>.bar \
    --java-version 17
```

The command compiles the Java project, embeds the resulting `MyAppJava.jar` inside the application's `.appzip`, and writes the BAR. No `--project` flag is needed - sibling discovery is automatic.

`--java-version` matches the JDK level the Java source targets. Default to `17` for new flows; use `8` only when the user has a Java-8-bound runtime constraint.

Successful build output looks like:
```
BIP8409I: Compiling Java project 'MyAppJava'
BIP1859I: Successfully added file 'MyAppJava.jar' to the BAR file.
BIP1853I: Application file 'MyApp.appzip' successfully added to the BAR file.
BIP8071I: Successful command completion.
```

---

## Phase B1 prompt

When the user describes a flow that hits one of the "use Java" triggers (MQ constant translation, library access, heavy parsing), surface this in Phase B1:

> "This needs Java for `<reason>`. I'll generate a sibling `<AppName>Java` project alongside `<AppName>` with the JCN nature and a `.classpath` set up for `<library>`. The application `.project` will reference the Java project under `<projects>`. OK?"

Don't silently add a Java project - surface the structural decision so the user knows what's coming.
