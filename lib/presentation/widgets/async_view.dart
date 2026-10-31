import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.data,
    this.expand = true,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => expand
          ? const Center(child: CircularProgressIndicator())
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: expand
            ? const Center(child: Text('Something went wrong loading this.'))
            : const Text('Something went wrong loading this.'),
      ),
      data: data,
    );
  }
}
