# webkit_inspection_protocol.dart

## 0.4.2
- Cast `HttpClientResponse` to `Stream<List<int>>` in response to
  SDK breaking change.

## 0.4.1
- Fix `page.reload` method.
- Disable implicit casts when developing this package.

## 0.4.0
- Change the `RemoteObject.value` return type to `Object`.

## 0.3.6
- Expose the `target` domain and additional `runtime` domain calls

## 0.3.5
- Widen the Dart SDK constraint

## 0.3.4
- Several fixes for strong mode at runtime issues
- Rename uses of deprecated dart:io constants

## 0.3.3
- Upgrade the Dart SDK minimum to 2.0.0-dev
- Rename uses of deprecated dart:convert constants

## 0.3.2
- Analysis fixes for strong mode
- Upgrade to the latest package dependencies

## 0.3.1
- Expose `ConsoleAPIEvent.timestamp`
- Expose `LogEntry.timestamp`

## 0.3.0
- Expose the `runtime` domain.
- Expose the `log` domain.
- Deprecated the `console` domain.
- Fix a bug in `Page.reload()`.
- Remove the use of parts.

## 0.2.2
- Make the package strong mode clean.

## 0.2.1+1

## 0.0.1

- Initial version (library moved out of the `grinder` package).
