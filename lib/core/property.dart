/// Observable property primitives ported from MCDSaveEdit's
/// `Core/Observables.cs` (Property / MappedProperty).

typedef PropertySubscriber<T> = void Function(T value);

abstract class ObservableBase<T> {
  final Set<PropertySubscriber<T>> _observers = {};

  void notifyListeners(T nextValue) {
    for (final observer in _observers.toList()) {
      observer(nextValue);
    }
  }

  void subscribe(PropertySubscriber<T> onNext) {
    _observers.add(onNext);
  }

  void unsubscribe(PropertySubscriber<T> onNext) {
    _observers.remove(onNext);
  }
}

abstract class IReadProperty<T> extends ObservableBase<T> {
  T get value;
}

abstract class IReadWriteProperty<T> extends IReadProperty<T> {
  set setValue(T value);
}

class Property<T> extends ObservableBase<T> implements IReadWriteProperty<T> {
  Property(this._value);

  T _value;

  @override
  T get value => _value;

  @override
  set setValue(T value) {
    _value = value;
    notifyListeners(value);
  }

  /// Force subscribers to re-run with the current value.
  void refresh() => notifyListeners(_value);
}

/// A property that maps a wrapped property through get/set closures.
/// Mirrors `MappedProperty<THidden, TVisible>`.
class MappedProperty<THidden, TVisible> extends ObservableBase<TVisible>
    implements IReadWriteProperty<TVisible> {
  MappedProperty(this._wrapped, this._getMethod, [this._setMethod]) {
    _wrapped.subscribe(_onHiddenChanged);
  }

  final IReadProperty<THidden> _wrapped;
  final TVisible Function(THidden)? _getMethod;
  final void Function(THidden hidden, TVisible value)? _setMethod;

  void _onHiddenChanged(THidden hiddenValue) {
    final mapped = _getMethod!(hiddenValue);
    notifyListeners(mapped);
  }

  @override
  TVisible get value => _getMethod!(_wrapped.value);

  @override
  set setValue(TVisible value) {
    _setMethod?.call(_wrapped.value, value);
    notifyListeners(value);
  }
}

extension PropertyMapExtension<THidden> on IReadProperty<THidden> {
  MappedProperty<THidden, TVisible> map<TVisible>(
    TVisible Function(THidden) getMethod, [
    void Function(THidden, TVisible)? setMethod,
  ]) {
    return MappedProperty<THidden, TVisible>(this, getMethod, setMethod);
  }
}
