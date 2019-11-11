use "buffered"
use "debug"
use "itertools"

primitive WriteTracks
  fun as_stereo_32_bit_aiff(sample_rate: USize, ltrack: Track, rtrack: Track,
    writer: Writer)
  =>
    let sound = Stereo32BitSoundDataChunk

    for (sl, sr) in Iter[F64](ltrack.samples().values()).zip[F64](rtrack.samples().values()) do
      let sla = (sl * I32.max_value().f64()).i32()
      let sra = (sr * I32.max_value().f64()).i32()
      sound.add_frame([sla; sra])
    end

    let common_chunk = CommonChunk(2, sound.num_frames().u32(), 32,
      sample_rate.f64())

    let form = FormAIFFChunk

    form .> add_chunk(common_chunk) .> add_chunk(sound)

    form.write(writer)

primitive Extended
  fun from_f64(x: F64): (U16, U64) =>
    let bits64 = x.bits()

    let s = (bits64 >> 63).u16()
    let e = ((bits64 and 0x7FF0000000000000) >> 52).i16()
    let e' = e - ((1 << 10) - 1)
    let e'' = (e' + ((1 << 14) - 1)).u16()

    let s_e = (s << 15) + e''

    let m = (bits64 and 0x000FFFFFFFFFFFFF)
    let m' = (m << 11) + 0x8000000000000000

    (s_e, m')

class FormAIFFChunk
  let _ck_id: String
  let _form_type: String
  let _chunks: Array[Chunk]

  new create() =>
    _ck_id = "FORM"
    _form_type = "AIFF"
    _chunks = Array[Chunk]

  fun write(buffer: Writer) =>
    var sz: U32 = 0

    for c in _chunks.values() do
      sz = sz + c.size()
    end

    sz + 4 // add 4 bytes for the form type field

    buffer.write(_ck_id.array())
    buffer.u32_be(sz)
    buffer.write(_form_type.array())

    for c in _chunks.values() do
      c.write(buffer)
    end

  fun ref add_chunk(chunk: Chunk) =>
    _chunks.push(chunk)

class CommonChunk
  let _ck_id: String
  let _ck_size: U32
  let _num_channels: I16
  let _num_sample_frames: U32
  let _sample_size: I16
  let _sample_rate: F64

  new create(num_channels: I16, num_sample_frames: U32, sample_size: I16,
    sample_rate: F64)
  =>
    _ck_id = "COMM"
    _ck_size = size()
    _num_channels = num_channels
    _num_sample_frames = num_sample_frames
    _sample_size = sample_size
    _sample_rate = sample_rate

  fun tag size(): U32 =>
    18

  fun write(buffer: Writer) =>
    buffer.write(_ck_id.array())
    buffer.u32_be(_ck_size)
    buffer.i16_be(_num_channels)
    buffer.u32_be(_num_sample_frames)
    buffer.i16_be(_sample_size)
    (let s_e, let m) = Extended.from_f64(_sample_rate)
    buffer.u16_be(s_e)
    buffer.u64_be(m)

class Stereo32BitSoundDataChunk
  let _ck_id: String
  let _offset: U32
  let _block_size: U32
  let _sound_data: Array[Array[I32]]

  new create(offset: U32 = 0, block_size: U32 = 0) =>
    _ck_id = "SSND"
    _offset = offset
    _block_size = block_size
    _sound_data = Array[Array[I32]]

  fun ref add_frame(frame: Array[I32]) =>
    _sound_data.push(frame)

  fun size(): U32 =>
    4 + 4 + (2 * 4 * _sound_data.size().u32())

  fun num_frames(): USize =>
    _sound_data.size()

  fun write(buffer: Writer) =>
    buffer.write(_ck_id.array())
    let sz: U32 = size()
    buffer.u32_be(sz)
    buffer.u32_be(_offset)
    buffer.u32_be(_block_size)

    for frame in _sound_data.values() do
      for sample in frame.values() do
        buffer.i32_be(sample)
      end
    end

type Chunk is (CommonChunk | Stereo32BitSoundDataChunk)
