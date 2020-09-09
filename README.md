## Aligning audio recordings with Julia

This is the companion repository for the blog post in https://rodrigo.red/blog/aligning-video-recordings-with-julia/

### Requirements

- [Julia 1.5+](https://julialang.org/)
- [Pluto.jl](https://github.com/fonsp/Pluto.jl/)
- [LibSndFile.jl](https://github.com/JuliaAudio/LibSndFile.jl)
- [FFTW.jl](https://github.com/JuliaMath/FFTW.jl)

### Running this notebook

```SH
# 1. Start Julia and install the requirements as needed
julia

# 2. Start Pluto and open the notebook in http://localhost:1234
import Pluto; Pluto.run(1234);
```

### Command line usage

#### Requirements

- [ffmpeg](https://ffmpeg.org/)

```SH
# The input files can be any video or audio file supported by ffmpeg
# Prints the offset in seconds
julia align-recordings.jl --within data/jazz-waves.ogg --find-offset-of data/jazz.ogg
```