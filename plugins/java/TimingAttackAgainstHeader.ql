import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import DataFlow::PathGraph


/** A static method that uses a non-constant-time algorithm for comparing inputs. */
private class NonConstantTimeComparisonCall extends StaticMethodAccess {
  NonConstantTimeComparisonCall() {
    this.getMethod()
        .hasQualifiedName("org.apache.commons.lang3", "StringUtils",
          ["equals", "equalsAny", "equalsAnyIgnoreCase", "equalsIgnoreCase"])
  }
}

/** Methods that use a non-constant-time algorithm for comparing inputs. */
private class NonConstantTimeEqualsCall extends MethodAccess {
  NonConstantTimeEqualsCall() {
    this.getMethod()
        .hasQualifiedName("java.lang", "String", ["equals", "contentEquals", "equalsIgnoreCase"])
  }
}

private predicate isNonConstantEqualsCallArgument(Expr e) {
  exists(NonConstantTimeEqualsCall call | e = [call.getQualifier(), call.getArgument(0)])
}

private predicate isNonConstantComparisonCallArgument(Expr p) {
  exists(NonConstantTimeComparisonCall call | p = [call.getArgument(0), call.getArgument(1)])
}

class ClientSuppliedIpTokenCheck extends DataFlow::Node {
  ClientSuppliedIpTokenCheck() {
    exists(MethodAccess ma |
      ma.getMethod().hasName("getHeader") and
      ma.getArgument(0).(CompileTimeConstantExpr).getStringValue().toLowerCase() in [
          "x-auth-token", "x-csrf-token", "http_x_csrf_token", "x-csrf-param", "x-csrf-header",
          "http_x_csrf_token", "x-api-key", "authorization", "proxy-authorization"
        ] and
      ma = this.asExpr()
    )
  }
}

class NonConstantTimeComparisonConfig extends TaintTracking::Configuration {
  NonConstantTimeComparisonConfig() { this = "NonConstantTimeComparisonConfig" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof ClientSuppliedIpTokenCheck
  }

  override predicate isSink(DataFlow::Node sink) {
    isNonConstantEqualsCallArgument(sink.asExpr()) or
    isNonConstantComparisonCallArgument(sink.asExpr())
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, NonConstantTimeComparisonConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Possible timing attack
