use "buffered"
use "collections"

actor Main
  new create(env: Env) =>
    let frames_per_second: USize = 44100

    let sound = Stereo32BitSoundDataChunk

    for a in Range[F64](0, Pi(2) * 13.5 * 60, Pi(2) / frames_per_second.f64()) do
      let standard: I32 = (1 << 30)
      let sample = ((a * 440).sin() * standard.f64()).i32()
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
