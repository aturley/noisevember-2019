type SndRawMidi is Pointer[U8]

primitive RawMidi
  fun snd_rawmidi_nonblock(): I32 => 2

primitive Midi
  fun get_channel(byte: U8): U8 =>
    byte and 0x0F

class NoteOnEvent
  var channel: U8 = 0
  var key: U8 = 0
  var velocity: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      key = bytes(1)?
      velocity = bytes(2)?
    end

  fun string(): String =>
    "note on: " + ",".join([channel; key; velocity].values())

class NoteOffEvent
  var channel: U8 = 0
  var key: U8 = 0
  var velocity: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      key = bytes(1)?
      velocity = bytes(2)?
    end

  fun string(): String =>
    "note off: " + ",".join([channel; key; velocity].values())

class ControlChangeEvent
  var channel: U8 = 0
  var control: U8 = 0
  var value: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      control = bytes(1)?
      value = bytes(2)?
    end

  fun string(): String =>
    "control change: " + ",".join([channel; control; value].values())

class ProgramChangeEvent
  var channel: U8 = 0
  var program: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      program = bytes(1)?
    end

  fun string(): String =>
    "program change: " + ",".join([channel; program].values())

class PitchBendChangeEvent
  var channel: U8 = 0
  var bend: U16 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      bend = bytes(1)?.u16() + (bytes(2)?.u16() << 7)
    end

  fun string(): String =>
    "pitch bend change: " + ",".join([channel; bend].values())

class KeyPressureEvent
  var channel: U8 = 0
  var key: U8 = 0
  var value: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      key = bytes(1)?
      value = bytes(2)?
    end

  fun string(): String =>
    "key pressure: " + ",".join([channel; key; value].values())

class ChannelPressureEvent
  var channel: U8 = 0
  var value: U8 = 0

  new create(bytes: Array[U8]) =>
    try
      channel = Midi.get_channel(bytes(0)?)
      value = bytes(1)?
    end

  fun string(): String =>
    "channel pressure: " + ",".join([channel; value].values())

type MidiEvent is (NoteOnEvent | NoteOffEvent | ControlChangeEvent
  | ProgramChangeEvent | PitchBendChangeEvent | KeyPressureEvent
  | ChannelPressureEvent)

primitive WaitingForStatus

primitive WaitingForNoteOnKey
primitive WaitingForNoteOnVelocity

primitive WaitingForNoteOffKey
primitive WaitingForNoteOffVelocity

primitive WaitingForCCControl
primitive WaitingForCCValue

primitive WaitingForProgram

primitive WaitingForPitchBendL
primitive WaitingForPitchBendM

primitive WaitingForKeyPressureKey
primitive WaitingForKeyPressureValue

primitive WaitingForChannelPressureValue

type MidiState is (WaitingForStatus
   | WaitingForNoteOnKey | WaitingForNoteOnVelocity
   | WaitingForNoteOffKey | WaitingForNoteOffVelocity
   | WaitingForCCControl | WaitingForCCValue
   | WaitingForProgram
   | WaitingForPitchBendL | WaitingForPitchBendM
   | WaitingForKeyPressureKey | WaitingForKeyPressureValue
   | WaitingForChannelPressureValue)

class MidiStateMachine
  var _state: MidiState = WaitingForStatus
  var _bytes: Array[U8] = Array[U8]

  new create() =>
    None

  fun ref apply(byte: U8): (None | MidiEvent) =>
    _bytes.push(byte)

    match _state
    | WaitingForStatus if _is_note_on(byte) =>
      _state = WaitingForNoteOnKey
    | WaitingForNoteOnKey =>
      _state = WaitingForNoteOnVelocity
    | WaitingForNoteOnVelocity =>
      _state = WaitingForStatus
      let e = NoteOnEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_note_off(byte) =>
      _state = WaitingForNoteOffKey
    | WaitingForNoteOffKey =>
      _state = WaitingForNoteOffVelocity
    | WaitingForNoteOffVelocity =>
      _state = WaitingForStatus
      let e = NoteOffEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_cc(byte) =>
      _state = WaitingForCCControl
    | WaitingForCCControl =>
      _state = WaitingForCCValue
    | WaitingForCCValue =>
      _state = WaitingForStatus
      let e = ControlChangeEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_program_change(byte) =>
      _state = WaitingForProgram
    | WaitingForProgram =>
      _state = WaitingForStatus
      let e = ProgramChangeEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_pitch_bend_change(byte) =>
      _state = WaitingForPitchBendL
    | WaitingForPitchBendL =>
      _state = WaitingForPitchBendM
    | WaitingForPitchBendM =>
      _state = WaitingForStatus
      let e = PitchBendChangeEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_key_pressure(byte) =>
      _state = WaitingForKeyPressureKey
    | WaitingForKeyPressureKey =>
      _state = WaitingForKeyPressureValue
    | WaitingForKeyPressureValue =>
      _state = WaitingForStatus
      let e = KeyPressureEvent(_bytes)
      _bytes.clear()
      return e
    | WaitingForStatus if _is_channel_pressure(byte) =>
      _state = WaitingForChannelPressureValue
    | WaitingForChannelPressureValue =>
      _state = WaitingForStatus
      let e = ChannelPressureEvent(_bytes)
      _bytes.clear()
      return e
    else
      // if nothing then throw away the byte and wait for the next one
      try _bytes.pop()? end
    end

    None

  fun _is_note_off(byte: U8): Bool =>
    (byte and 0xF0) == 0x80

  fun _is_note_on(byte: U8): Bool =>
    (byte and 0xF0) == 0x90

  fun _is_key_pressure(byte: U8): Bool =>
    (byte and 0xF0) == 0xA0

  fun _is_cc(byte: U8): Bool =>
    (byte and 0xF0) == 0xB0

  fun _is_program_change(byte: U8): Bool =>
    (byte and 0xF0) == 0xC0

  fun _is_channel_pressure(byte: U8): Bool =>
    (byte and 0xF0) == 0xD0

  fun _is_pitch_bend_change(byte: U8): Bool =>
    (byte and 0xF0) == 0xE0

trait MidiNotify
  fun ref note_on(channel: U8, key: U8, velocity: U8) =>
    None

  fun ref note_off(channel: U8, key: U8, velocity: U8) =>
    None

  fun ref key_pressure(channel: U8, key: U8, value: U8) =>
    None

  fun ref control_change(channel: U8, control: U8, value: U8) =>
    None

  fun ref program_change(channel: U8, program: U8) =>
    None

  fun ref channel_pressure(channel: U8, value: U8) =>
    None

  fun ref pitch_bend_change(channel: U8, bend: U16) =>
    None

actor MidiReceiver
  var _midiin: SndRawMidi
  let _midi_state_machine: MidiStateMachine = MidiStateMachine
  let _midi_notify: MidiNotify

  new create(midi_device_name: String, out: OutStream, midi_notify: MidiNotify iso) =>
    let mode: I32 = RawMidi.snd_rawmidi_nonblock()
    _midiin = SndRawMidi
    _midi_notify = consume midi_notify

    out.print("preparing MIDI")

    match @snd_rawmidi_open[I32](addressof _midiin, Pointer[U8], midi_device_name.cstring(), mode)
    | let err: I32 if err < 0 =>
      out.print("problem opening MIDI input: " + String.copy_cstring(@snd_strerror[CString](err)))
      return
    end

    out.print("MIDI ready!")

    out.print("MIDI reading")

    _listen(out)

  be _listen(out: OutStream) =>
    let eagain: I32 = 11
    let ebusy: I32 = 16

    let buffer = Array[U8].init(0, 1)

    let status = @snd_rawmidi_read[I32](_midiin, buffer.cpointer(), USize(1))

    if (status  < 0) and (status != -ebusy) and (status != -eagain) then
      out.print("problem reading MIDI input: " + String.copy_cstring(@snd_strerror[CString](status)))
    elseif (status >= 0) then
      try
        out.print("got: " + buffer(0)?.string())
        match _midi_state_machine(buffer(0)?)
        | let e: NoteOffEvent =>
          out.print("notify:" + e.string())
          _midi_notify.note_off(e.channel, e.key, e.velocity)
        | let e: NoteOnEvent =>
          out.print("notify:" + e.string())
          _midi_notify.note_on(e.channel, e.key, e.velocity)
        | let e: KeyPressureEvent =>
          out.print("notify:" + e.string())
          _midi_notify.key_pressure(e.channel, e.key, e.value)
        | let e: ControlChangeEvent =>
          out.print("notify:" + e.string())
          _midi_notify.control_change(e.channel, e.control, e.value)
        | let e: ProgramChangeEvent =>
          out.print("notify:" + e.string())
          _midi_notify.program_change(e.channel, e.program)
        | let e: ChannelPressureEvent =>
          out.print("notify:" + e.string())
          _midi_notify.channel_pressure(e.channel, e.value)
        | let e: PitchBendChangeEvent =>
          out.print("notify:" + e.string())
          _midi_notify.pitch_bend_change(e.channel, e.bend)
        end
      end
    end

    _listen(out)

