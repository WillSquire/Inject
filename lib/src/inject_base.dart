// Copyright (c) 2015, Will Squire. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// TODO import StreamTrigger as streamTrigger, so this will be streamTrigger.TriggerHandle

library inject.base;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:mirrors'; // TODO This need replacing with a client side friendly reflection package
import 'package:stream_trigger/stream_trigger.dart';

class InjectModule
{
  //-------------------------------------------------------------------------------------------
  // Variables - Public
  //-------------------------------------------------------------------------------------------

  Map<String,Object> get dataMap => _dataMap;
  File get file => _file;
  String get prefix => _prefix;
  String get suffix => _suffix;

  //-------------------------------------------------------------------------------------------
  // Variables - Private
  //-------------------------------------------------------------------------------------------

  Map<String,Object> _dataMap;
  Map<List<int>,Object> _utf8DataMap;
  File _file;
  StreamTrigger _streamTrigger;
  String _prefix;
  String _suffix;
  List<int> _utfPrefix;
  List<int> _utfSuffix;
  StreamController _controller;
  StreamSubscription _subscription;
  List<Stream<List<int>>> _streams; // Streams queue
  bool _sync = true;
  bool _cancelOnError = true;
  //List<String> ignoredCharacters = [' ']; // Ignore spaces by default

  //-------------------------------------------------------------------------------------------
  // Functions - Constructor
  //-------------------------------------------------------------------------------------------

  /**
   * Maps values from Map keys to data in a module
   *
   * URI is the location of the resource module to be injected into and DataMap
   * is the map object of which the key names will be searched in
   * the target URI for the value to be 'injected' at these points
   */
  InjectModule(File this._file, Map<String,Object> this._dataMap, [String this._prefix, String this._suffix])
  {
    _initialiseTriggers();
    _initialiseStream();
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Maps values from data model variables to data in a module
   *
   * URI is the location of the resource module to be injected into and the data
   * model is the object of which the property names will be searched in the
   * target URI for the value to be 'injected' at these points
   */
  InjectModule.fromObject(File this._file, Object dataModel, [String this._prefix, String this._suffix])
  {
    _dataMap = _objectToMap(dataModel);
    _initialiseTriggers();
    _initialiseStream();
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Public
  //-------------------------------------------------------------------------------------------

  /**
   * Process
   *
   * Returns the the stream this class outputs.
   */
  Stream<List<int>> process()
  {
    return _controller.stream;
  }

  //-------------------------------------------------------------------------------------------
  // Functions - Private
  //-------------------------------------------------------------------------------------------

  /**
   * Initialise data map
   *
   * Creates new key/value pair map of pattern/data to map to occurring
   * pattern.
   */
  void _initialiseTriggers()
  {
    _utf8DataMap = _stringKeysToUTF8(_dataMap);

    if (_prefix != null)
    {
      _utfPrefix = UTF8.encode(_prefix);

      if (_suffix != null)
        _utfSuffix = UTF8.encode(_suffix);
    }

    _streamTrigger = new StreamTrigger(_resetTriggerHandle());
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Set reset trigger handles
   *
   * Wrapper object essentially, adds the reset trigger handle
   * to StreamTrigger and always returns null as not to inject
   * into stream.
   */
  Null _setResetTriggerHandles()
  {
    _streamTrigger.setTriggers(_resetTriggerHandle());

    return null;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Reset handler
   *
   * Returns the handler for resetting trigger handles back
   * to the default state.
   */
  Map<List<int>,TriggerHandle> _resetTriggerHandle()
  {
    Map<List<int>,TriggerHandle> triggerHandles = new Map<List<int>,TriggerHandle>();

    if (_prefix != null)
    {
      // Add prefix trigger
      triggerHandles.addAll(_prefixTriggerHandle());
    }
    else
    {
      // Add command triggers
      triggerHandles.addAll(_injectHandles());
    }

    return triggerHandles;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Prefix trigger
   *
   * Returns a Map with the prefix trigger and handler.
   */
  Map<List,TriggerHandle> _prefixTriggerHandle()
  {
    return {
        _utfPrefix : ()
        {
          Map<List<int>,TriggerHandle> triggerHandles = new Map<List<int>,TriggerHandle>();

          // Adds itself in case one trigger disables this, then the prefix trigger occurs during contested
          triggerHandles.addAll(_prefixTriggerHandle());

          if (_suffix != null)
          {
            // Add command and suffix triggers (allow spaces)
            triggerHandles.addAll(_injectHandles());
            triggerHandles.addAll(_suffixTriggerHandle());
          }
          else
          {
            // Add command and space triggers (don't allow spaces and revert when command complete)
            triggerHandles.addAll(_injectTriggerHandlesWithReset());
            triggerHandles.addAll(_spaceResetTrigger());
          }

          _streamTrigger.setTriggers(triggerHandles);

          return null;
        }
    };
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Suffix trigger
   *
   * Returns a Map with the suffix trigger and handler.
   */
  Map<List,TriggerHandle> _suffixTriggerHandle()
  {
    return {
        _utfSuffix : () => _setResetTriggerHandles()
    };
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Initialise Stream
   *
   * Creates a stream that outputs the results of all different
   * files and compiles in a sequential fashion.
   */
  void _initialiseStream()
  {
    _streams = new List<Stream<List<int>>>();

    _addStream(
        _file.openRead()
        .transform(_streamTrigger)
    );

    _controller = new StreamController<List<int>>
    (
        onListen: _listen,
        onCancel: _onCancel,
        onPause: () { _subscription.pause(); },
        onResume: () { _subscription.resume(); },
        sync: _sync
    );
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Trigger handles
   *
   * Returns triggers and corresponding handles from the utf data map.
   */
  Map<List<int>,TriggerHandle> _injectHandles()
  {
    Map<List<int>,TriggerHandle> triggerHandles = new Map<List<int>,TriggerHandle>();

    _utf8DataMap.forEach((List<int> k, Object v)
    {
      /*
      switch (v.runtimeType)
      {
        case InjectModule:
          triggerHandles[k] = () => v.process();
          break;
        case Stream:
          triggerHandles[k] = () => v;
          break;
        case String:
          triggerHandles[k] = () => UTF8.encode(v);
          break;
        default:
          triggerHandles[k] = () => UTF8.encode(v.toString());
      }
      */

      if (v is InjectModule)
        triggerHandles[k] = () => v.process();
      else if (v is String)
        triggerHandles[k] = () => UTF8.encode(v);
      else if (v is Stream<List<int>>)
        triggerHandles[k] = () => v;
      else
        triggerHandles[k] = () => UTF8.encode(v.toString());

    });

    return triggerHandles;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Inject trigger handles with reset
   *
   * Returns triggers and corresponding handles from the utf data map,
   * the 'trigger' is what pattern/sequence of element/s are to be
   * detected on the stream and the handler is callback function is
   * called once this occurs. This also resets StreamTrigger's trigger
   * handles after triggering.
   */
  Map<List<int>,TriggerHandle> _injectTriggerHandlesWithReset()
  {
    Map<List<int>,TriggerHandle> triggerHandles = new Map<List<int>,TriggerHandle>();

    _utf8DataMap.forEach((List<int> k, Object v)
    {
      /*
      switch (v.runtimeType)
      {
        case InjectModule:
          triggerHandles[k] = ()
          {
            _setResetTriggerHandles();
            return v.process();
          };
          break;
        case Stream:
          triggerHandles[k] = ()
          {
            _setResetTriggerHandles();
            return v;
          };
          break;
        case String:
          triggerHandles[k] = ()
          {
            _setResetTriggerHandles();
            return UTF8.encode(v);
          };
          break;
        default:
          triggerHandles[k] = ()
          {
            _setResetTriggerHandles();
            return UTF8.encode(v.toString());
          };
      }
      */
      if (v is InjectModule)
        triggerHandles[k] = ()
        {
          _setResetTriggerHandles();

          return v.process();
        };
      else if (v is String)
        triggerHandles[k] = ()
        {
          _setResetTriggerHandles();

          return UTF8.encode(v);
        };
      else if (v is Stream<List<int>>)
        triggerHandles[k] = ()
        {
          _setResetTriggerHandles();

          return v;
        };
      else
        triggerHandles[k] = ()
        {
          _setResetTriggerHandles();

          return UTF8.encode(v.toString());
        };
    });

    return triggerHandles;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Space reset trigger
   *
   * Returns trigger and corresponding handler for
   * resetting to initial state upon a space.
   */
  Map<List<int>,TriggerHandle> _spaceResetTrigger()
  {
    return {
        UTF8.encode(" ") : () => _setResetTriggerHandles()
    };
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Add new stream
   *
   * Add a new stream reading from the selected file (streams can
   * be paused and others can be fed in instead).
   */
  void _addStream(Stream<List<int>> s)
  {
    _streams.add(s);
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Listen to next stream
   *
   * Try to listen to the next stream if present. If no other streams
   * are present, close this outputting stream.
   */
  void _listen()
  {
    _subscription = _streams.first.listen
    (
        _controller.add,
        onError: _controller.addError,
        onDone: _done,
        cancelOnError: _cancelOnError
    );
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Input stream is done
   *
   * Check for other input streams to listen to, else if non exist close
   * the outputted stream also.
   */
  void _done()
  {
    _streams.removeAt(0);

    if (_streams.length == 0)
    {
      //_subscription = null;
      _controller.close();
    }
    else
    {
      _listen();
    }
  }

  //-------------------------------------------------------------------------------------------

  /**
   * On cancelling listening to this stream
   *
   * Cancel and remove all subscriptions that only this stream
   * depends on.
   */
  void _onCancel()
  {
    _subscription.cancel();
    _subscription = null;
    _streams.clear();
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Creates a Map from an Object
   *
   * Uses refection (mirrors) to produce a Map (array) from an object's
   * variables. Making the variable name the key, and it's value the
   * value.
   */
  Map<String,Object> _objectToMap(Object object)
  {
    // Mirror the particular instance (rather than the class itself)
    InstanceMirror instanceMirror = reflect(object);
    Map<String,String> dataMapped = new Map<String,String>();

    // Mirror the instance's class (type) to get the declarations
    for (var declaration in instanceMirror.type.declarations.values)
    {
      // If declaration is a type of variable, map variable name and value
      if (declaration is VariableMirror)
      {
        String variableName = MirrorSystem.getName(declaration.simpleName);
        Object variableValue = instanceMirror.getField(declaration.simpleName).reflectee;

        dataMapped[variableName] = variableValue;
      }
    }

    return dataMapped;
  }

  //-------------------------------------------------------------------------------------------

  /**
   * Encodes Map keys in UTF-8 encoding
   *
   * Converts a Map using Strings as keys into a new Map that
   * encodes the keys into UTF-8 Int types. Useful for streams
   * as both the data on the stream and the Map lookup will be in
   * the same format. Note, if Map data is not of the String type,
   * super class's toString() is called to convert to string.
   */
  Map<List<int>,Object> _stringKeysToUTF8(Map<String,Object> stringMap)
  {
    Map<List<int>,Object> utfMap = new Map<List<int>,Object>();

    stringMap.forEach((String key, Object value)
    {
      utfMap[UTF8.encode(key)] = value;
    });

    return utfMap;
  }
}