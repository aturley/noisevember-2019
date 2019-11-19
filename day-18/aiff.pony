use "buffered"
use "collections"
use "debug"
use "itertools"

primitive ReadFormChunk
  fun apply(data: Array[U8] val, reader: Reader, out: OutStream): Array[U8] val ? =>
    reader.append(data)
    (let ck_id, let size, let form_type, let chunks) = _read_form(reader)?
    out.print("ck_id=" + ck_id + " size=" + size.string() + " from_type=" + form_type)
    chunks

  fun _read_form(reader: Reader): (String, U32, String, Array[U8] val) ? =>
    let ck_id = String.from_array(reader.block(4)?)
    let size = reader.u32_be()?
    let form_type = String.from_array(reader.block(4)?)
    let chunks: Array[U8] val = reader.block(size.usize() - 4)?

    (ck_id, size, form_type, chunks)

primitive ReadCommonChunk
  fun apply(data: Array[U8] val, reader: Reader, out: OutStream): (I16, I16) ? =>
    reader.append(data)
    (let ck_id, let size, let num_channels, let num_sample_frames, let sample_size, let sample_rate) = _read_common(reader)?
    out.print("ck_id=" + ck_id + " size=" + size.string() + " num_channels=" + num_channels.string() + " sample_size=" + sample_size.string() + " sr=" + sample_rate.string())
    (num_channels, sample_size)

  fun _read_common(reader: Reader): (String, U32, I16, U32, I16, F64) ? =>
    let ck_id = String.from_array(reader.block(4)?)
    let size = reader.u32_be()?
    let num_channels = reader.i16_be()?
    let num_sample_frames = reader.u32_be()?
    let sample_size = reader.i16_be()?
    let sr_exp = reader.u16_be()?
    let sr_mant = reader.u64_be()?
    let sample_rate = Extended.to_f64(sr_exp, sr_mant)

    (ck_id, size, num_channels, num_sample_frames, sample_size, sample_rate)

primitive ReadSoundDataChunk
  fun apply(reader: Reader, out: OutStream, num_channels: I16, sample_size: I16): Array[Array[F64]] ? =>
    (let ck_id, let size, let offset, let block_size, let sound_data) = _read_sound(reader)?

    out.print("ck_id=" + ck_id + " size=" + size.string() + " offset=" + offset.string() + " block_size=" + block_size.string() + " sound_data.size()=" + sound_data.size().string())

    let samples = Array[Array[F64]](num_channels.usize())

    for _ in Range(0, num_channels.usize()) do
      samples.push(Array[F64])
    end

    let num_samples = (size - 8).usize() / (num_channels.usize() * (sample_size.usize() / 8))

    let sound_data_it = sound_data.values()

    for _ in Range(0, num_samples) do
      for c in Range(0, num_channels.usize()) do
        var sample: I64 = 0

        for _ in Range(0, sample_size.usize() / 8) do
          sample = (sample << 8) + (try sound_data_it.next()? else 0 end).i64()
        end

        let sign = sample >> (sample_size.u64() - 1)

        let sample' = if sign == 0 then
          sample
        else
          sample + (I64(-1) << sample_size.u64())
        end

        let f_sample = sample'.f64() / (1 << (sample_size.u64() - 1)).f64()
        out.print("sample'=" + sample'.string() + " f_sample=" + f_sample.string())

        try
          samples(c)?.push(f_sample)
        end
      end
    end

    samples

  fun _read_sound(reader: Reader): (String, U32, U32, U32, Array[U8] val) ? =>
    let ck_id = String.from_array(reader.block(4)?)
    let size = reader.u32_be()?
    let offset = reader.u32_be()?
    let block_size = reader.u32_be()?
    let sound_data = reader.block(size.usize() - 8)?

    (ck_id, size, offset, block_size, sound_data)

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

  fun to_f64(s_e: U16, m: U64): F64 =>
    let s = (s_e >> 15).u64()
    let e = (s_e and 0x7FFF).u64()
    let e' = e - ((1 << 14) - 1)
    let e'' = e' + ((1 << 10) - 1)
    let e''' = e'' << 52

    let m' = ((m - 0x8000000000000000) >> 11)

    let bits: U64 = (s << 63) + e''' + m'

    F64.from_bits(bits)

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
