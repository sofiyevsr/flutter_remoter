import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_remoter/src/remoter_provider.dart';
import 'package:remoter/remoter.dart';

class RemoterQuery<T> extends StatefulWidget {
  final String remoterKey;
  final Future<T> Function() fn;
  final Widget Function(BuildContext, RemoterData<T>?) builder;
  final Function(RemoterData<T> oldState, RemoterData<T> newState)? listener;
  const RemoterQuery({
    super.key,
    this.listener,
    required this.remoterKey,
    required this.fn,
    required this.builder,
  });

  @override
  State<RemoterQuery<T>> createState() => _RemoterQueryState<T>();
}

class _RemoterQueryState<T> extends State<RemoterQuery<T>> {
  StreamSubscription<RemoterData<T>>? subscription;
  late RemoterData<T> data;

  RemoterData<T> _startStream() {
    subscription?.cancel();
    final provider = RemoterProvider.of(context);
    provider.client.fetch<T>(widget.remoterKey, widget.fn);
    subscription = provider.client.getStream<T>(widget.remoterKey).listen(
      (event) {
        if (widget.listener != null) widget.listener!(data, event);
        setState(() {
          data = event;
        });
      },
    );
    return provider.client.getData<T>(widget.remoterKey) ??
        RemoterData<T>(
          key: widget.remoterKey,
          data: null,
          status: RemoterStatus.fetching,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (subscription != null) return;
    data = _startStream();
  }

  @override
  void didUpdateWidget(RemoterQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remoterKey == widget.remoterKey) return;
    final newData = _startStream();
    setState(() {
      data = newData;
    });
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
