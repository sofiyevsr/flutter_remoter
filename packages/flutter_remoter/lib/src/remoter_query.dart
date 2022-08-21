import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/remoter_provider.dart';
import 'package:remoter/remoter.dart';

class RemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final Future<T> Function() fn;
  final Widget Function(BuildContext, RemoterData<T>?) builder;
  const RemoterQuery({
    super.key,
    required this.remoterKey,
    required this.fn,
    required this.builder,
  });

  @override
  State<RemoterQuery<T>> createState() => _RemoterQueryState<T>();
}

class _RemoterQueryState<T> extends State<RemoterQuery<T>> {
  StreamSubscription<RemoterData<T>>? subscription;
  RemoterData<T>? data;

  void _startStream() {
    subscription?.cancel();
    final provider = RemoterProvider.of(context);
    provider.client.fetch<T>(widget.remoterKey, widget.fn);
    subscription = provider.client.getStream<T>(widget.remoterKey).listen(
      (event) {
        setState(() {
          data = event;
        });
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    _startStream();
  }

  @override
  void didUpdateWidget(RemoterQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remoterKey == widget.remoterKey) return;
    setState(() {
      data = null;
    });
    _startStream();
  }

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        data,
      );
}
