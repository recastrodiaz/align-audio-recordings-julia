using FileIO: load
import LibSndFile
using SampledSignals
using FFTW
using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--within"
            help = "video/audio as input to be aligned with --with"
            required = true
        "--find-offset-of"
            help = "another video/audio file"
            required = true
    end

    return parse_args(s)
end

function main()
    # Parse the program parameters
    parsed_args = parse_commandline()
    input_filepath = parsed_args["within"]
    find_offest_input_filepath = parsed_args["find-offset-of"]

    # Convert the input files to ogg, samplerate of 16KHz
    convert_to_audio(input_filepath)
    convert_to_audio(find_offest_input_filepath)

    # Load the audio files
    audio_1 = load(audio_filepath(input_filepath))
    audio_2 = load(audio_filepath(find_offest_input_filepath))

    # Pad the signals
    audio_max_size = 2 * max(length(audio_2), length(audio_1))

    audio_1_padded = padded(audio_1, audio_max_size)
    audio_2_padded = padded(audio_2, audio_max_size)
    audio_2_padded_reversed = reverse(audio_2_padded, dims=1)

    # Perform the convolutions
    convolution = irfft(rfft(audio_1_padded) .* rfft(audio_2_padded_reversed), length(audio_1_padded))

    # Find the lag in seconds
    peak_bin, peak_value = argmax(convolution[:, 1]), maximum(convolution[:, 1])
    lag_seconds = peak_bin / audio_1.samplerate
    # The FFT performs a ciruclar convolution, so the peak_value can be on the second half of the padded audio signal
    # which would be longer than the audio file itself. Ensure the offset is lower than the length of the audio file.
    convolution_length_seconds =  length(convolution[:, 1]) / audio_1.samplerate
    lag_seconds = min(lag_seconds, convolution_length_seconds - lag_seconds)

    # Improve the lag 
    p = interpolate(convolution[:, 1], peak_bin)
    lag_seconds_improved = lag_seconds + p / audio_1.samplerate

    println(lag_seconds_improved)
end

function convert_command(filepath)
    output_filepath = audio_filepath(filepath)
    return `ffmpeg -i $filepath -vn -ar 16000 -ac 1 $output_filepath -n`
end

function audio_filepath(filepath)
    # Keep the actual filename, but not the folders
    parts = rsplit(filepath, "/"; limit=2)
    return "$(tempdir())/$(parts[length(parts)]).ogg"
end

function convert_to_audio(filepath)
    if (!isfile(audio_filepath(filepath)))
        run(convert_command(filepath))
    end
end
    
function padded(audio, expected_size)
    pad_size = expected_size - length(audio)
    audio_pad = SampledSignals.SampleBuf(zeros(Float32, pad_size, 1), audio.samplerate)
    audio_padded = vcat(audio, audio_pad) 

    return audio_padded
end

function interpolate(signal, peak_bin)
    # Quadratic Interpolation of Spectral Peaks
    # https://ccrma.stanford.edu/~jos/sasp/Quadratic_Interpolation_Spectral_Peaks.html
    α = signal[peak_bin - 1]
    β = signal[peak_bin]
    γ = signal[peak_bin + 1]

    p = 1 / 2 * (α - γ) / (α - 2 * β + γ)
return p
end

main()