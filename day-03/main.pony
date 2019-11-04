use "buffered"
use "collections"
use "itertools"

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100
    let freq: F64 = 440
    let total_frames = frames_per_second * 2

    let sound = Stereo32BitSoundDataChunk

    let gen = Gen01(512, [as (USize, F64):
      (0, 0)
      (50, 0.999)
      (205, 0.999)
      (306, -0.999)
      (461, -0.999)
      (512, 0)])

    for gs in Iter[F64](gen.samples(freq, frames_per_second)).take(total_frames) do
      let sample = (gs * I32.max_value().f64()).i32()
      sound.add_frame([sample; sample])
    end

    let common_chunk = CommonChunk(2, sound.num_frames().u32(), 32, frames_per_second.f64())

    let form = FormAIFFChunk

    form .> add_chunk(common_chunk) .> add_chunk(sound)

    let writer: Writer ref = Writer

    form.write(writer)

    env.out.writev(writer.done())

primitive Pi
  fun apply(n: F64 = 1 , d: F64 = 1): F64 =>
    (3.1415926535 * n) / d
