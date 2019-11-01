# Noisevember 2019 -- Day 1

## Goal

Write a standalone program that generates an AIFF audio file.

## Result

I put together a library to create [AIFF
files](http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/AIFF-1.3.pdf),
and then generated a [13.5 minute file that's just a 440 Hz sine
wave](https://twitter.com/casio_juarez/status/1049488788798562304?s=20).

The AIFF standard isn't too bad to work with, other than the fact that
some things are represented by 80-bit IEEE extended floating point
numbers, which I had to implement myself. Most of my time was spent
doing that.

To build it:

```
ponyc
```

To run it:

```
./day-01 > test.aiff
```

[LISTEN](https://soundcloud.com/aturley/135-minute-sine-wave)
