use "lib:asound"

use "collections"

type CString is Pointer[U8]

type SndPCM is Pointer[U8]
type SndPCMHWParams is Pointer[U8]
type SndPCMSWParams is Pointer[U8]
type SNDPCMSFrames is I32

primitive PCM
  fun snd_pcm_stream_playback(): I32 => 0
  fun snd_pcm_access_rw_interleaved(): I32 => 3
  fun snd_pcm_form_s16_le(): I32 => 2
  fun snd_pcm_form_s16_be(): I32 => 3

class PlayerNotify is MidiNotify
  let _player: Player

  new iso create(player: Player) =>
    _player = player

  fun ref note_on(channel: U8, key: U8, velocity: U8) =>
    if velocity > 0 then
      _player.set_note_on(key, velocity)
    else
      _player.set_note_off(key, velocity)
    end

  fun ref note_off(channel: U8, key: U8, velocity: U8) =>
    _player.set_note_off(key, velocity)

class Oscillator
  var _wave_pos: F64 = 0
  var _wave_step: F64 = 0

  fun ref set_freq(f: F64) =>
    _wave_step = (F64.pi() * 2) / (44100 / f)

  fun ref next(): F64 =>
    let n = _wave_pos.sin()
    _wave_pos = _wave_pos + _wave_step
    n

class Envelope
  var _velocity: F64

  new create() =>
    _velocity = 0

  fun ref on() =>
    _velocity = 1

  fun ref off() =>
    _velocity = 0

  fun ref next(): F64 =>
    _velocity

actor Main
  new create(env: Env) =>
    let alsa_device_name = try env.args(1)? else "default" end
    let player = Player.create(alsa_device_name, env.err)

    let midi_device_name = try env.args(2)? else "default" end
    MidiReceiver(midi_device_name, env.err, PlayerNotify(player))

actor Player
  let _oscillators: Array[(Envelope, Oscillator)]

  var _buf: Array[I16] = Array[I16](4096 * 2)
  var _wave_pos: F64 = 0
  var _wave_step: F64 = (F64.pi() * 2) / (44100 / 440)
  var _last_wave_step: F64

  var _playback_handle: SndPCM

  new create(alsa_device_name: String, out: OutStream, num_osc: USize = 8) =>
    _oscillators = _oscillators.create(num_osc)

    for n in Range[F64](0, 128) do
      let o: Oscillator = Oscillator .> set_freq(MidiToFreq(n))
      let e = Envelope
      _oscillators.push((e, o))
    end

    _playback_handle = SndPCM

    _last_wave_step = _wave_step

    var hw_params = SndPCMHWParams
    var sw_params = SndPCMSWParams

    match @snd_pcm_open[I32](addressof _playback_handle, alsa_device_name.cstring(), PCM.snd_pcm_stream_playback(), U32(0))
    | let err: I32 if err < 0 =>
      out.print("cannot open audio device " + alsa_device_name + " (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("opened\n".cstring())

    // set HW params

    match @snd_pcm_hw_params_malloc[I32](addressof hw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot allocate hardware parameter structure (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("malloced\n".cstring())

    match @snd_pcm_hw_params_any[I32](_playback_handle, hw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot allocate hardware parameter structure (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("anyed\n".cstring())

    match @snd_pcm_hw_params_set_access[I32](_playback_handle, hw_params, PCM.snd_pcm_access_rw_interleaved())
    | let err: I32 if err < 0 =>
      out.print("cannot set access type (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("accessed\n".cstring())

    match @snd_pcm_hw_params_set_format[I32](_playback_handle, hw_params, PCM.snd_pcm_form_s16_le())
    | let err: I32 if err < 0 =>
      out.print("cannot set access type (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("access typed\n".cstring())

    var rate = U32(44100)
    var dir = U32(0)

    match @snd_pcm_hw_params_set_rate_near[I32](_playback_handle, hw_params, addressof rate, addressof dir)
    | let err: I32 if err < 0 =>
      out.print("cannot set sample rate (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("rate set\n".cstring())

    match @snd_pcm_hw_params_set_channels[I32](_playback_handle, hw_params, U32(2))
    | let err: I32 if err < 0 =>
      out.print("cannot set channel count (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("channels set\n".cstring())

    var buffer_size = U32(4096)

    match @snd_pcm_hw_params_set_buffer_size_near[I32](_playback_handle, hw_params, addressof buffer_size)
    | let err: I32 if err < 0 =>
      out.print("cannot set buffer size (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_hw_params[I32](_playback_handle, hw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot set parameters (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    @printf[I32]("params set\n".cstring())

    @snd_pcm_hw_params_free[None](hw_params)

    // set SW params

    match @snd_pcm_sw_params_malloc[I32](addressof sw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot allocate software parameter structure (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_sw_params_current[I32](_playback_handle, sw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot initialize software parameter structure (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_sw_params_set_avail_min[I32](_playback_handle, sw_params, U32(4096))
    | let err: I32 if err < 0 =>
      out.print("cannot set minimum available count (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_sw_params_set_start_threshold[I32](_playback_handle, sw_params, U32(0))
    | let err: I32 if err < 0 =>
      out.print("cannot set start mode (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_sw_params[I32](_playback_handle, sw_params)
    | let err: I32 if err < 0 =>
      out.print("cannot set software parameters (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_prepare[I32](_playback_handle)
    | let err: I32 if err < 0 =>
      out.print("cannot prepare audio interface for use (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    match @snd_pcm_wait[I32](_playback_handle, U32(1000))
    | let err: I32 if err < 0 =>
      out.print("cannot prepare audio interface for use (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
      return
    end

    _play_loop(out)

  be _play_loop(out: OutStream) =>
    try
      let frames_to_deliver = match @snd_pcm_avail_update[SNDPCMSFrames](_playback_handle)
      | let ftd: I32 if ftd > 4096 =>
        4096
      | let ftd: I32 if ftd >= 0 =>
        ftd
      | let err: I32 =>
        out.print("error getting available frames (" + err.string() + ")")
        error
      end

      match playback_call(frames_to_deliver, _playback_handle)
      | let err: I32 if err != frames_to_deliver =>
        out.print("playback call failed (" + String.copy_cstring(@snd_strerror[CString](err)) + ")")
        error
      end

      if _last_wave_step != _wave_step then
        _last_wave_step = _wave_step
        out.print("wave step changed")
      end

      _play_loop(out)
    end

  fun ref playback_call(nframes: SNDPCMSFrames, playback_handle: SndPCM): I32 =>
    _buf.clear()

    for i in Range(0, nframes.usize()) do
      var sum: F64 = 0

      for (e, o) in _oscillators.values() do
        sum = sum + (e.next() * o.next())
      end

      _buf.push((sum * 0.1 * I16.max_value().f64()).i16())
      _buf.push((sum * 0.1 * I16.max_value().f64()).i16())
    end

    match @snd_pcm_writei[I32](playback_handle, _buf.cpointer(), nframes)
    | let err: I32 if err < 0 =>
      return err
    end

    nframes

  be set_note_on(note: U8, velocity: U8) =>
    @printf[I32]("received note %d\n".cstring(), note)

    try
      let idx = note.usize()
      (let e, _) = _oscillators(idx)?
      e.on()
    end

  be set_note_off(note: U8, velocity: U8) =>
    try
      let idx = note.usize()
      (let e, _) = _oscillators(idx)?
      e.off()
    end

primitive MidiToFreq
  fun apply(m: F64): F64 =>
    let two: F64 = 2
    two.pow((m - 69) / 12) * 440
