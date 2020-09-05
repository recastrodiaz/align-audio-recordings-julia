### A Pluto.jl notebook ###
# v0.11.10

using Markdown
using InteractiveUtils

# ╔═╡ b16a96ca-eba3-11ea-3a74-4fecb5dda838
begin
	using FileIO: load
	import LibSndFile
	using Plots
	using SampledSignals
	using FFTW
end

# ╔═╡ cf3ddc9c-ebab-11ea-1417-b7eb9e517b50
md"# Aligning video recordings with Julia"

# ╔═╡ 2c57c0fe-ed5b-11ea-2837-81321cf21495
md"Due to the restrictions imposed by COVID-19, dance teachers around the world are taking their classes online. As a dance student, it would be helpful to watch yourself against a recording of your teacher.

Something like this:"

# ╔═╡ 34a5c400-ebd9-11ea-04cf-3118b3902453
html"<iframe width=\"680\" height=\"383\" src=\"https://www.youtube-nocookie.com/embed/I8kuhv0FcTE\" frameborder=\"0\" allow=\"accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"

# ╔═╡ ae29c670-ebd9-11ea-3995-77063c4c3f4d
md"It is very unlikely the song in both videos starts at exactly the same. Manually syncing them is not easy.

On the other hand, computers can compare the sound waves of each video file and quickly determine how long to wait before playing one video or the other so they are both aligned."

# ╔═╡ eb4bd808-ebc9-11ea-3c71-e9850bb24137
md"## Sound waves"

# ╔═╡ f7a9d13a-ebac-11ea-2abd-79345ce6fbef
md"[Sound waves](https://pudding.cool/2018/02/waveforms/) are represented in digital audio by very rapidly sampling the distortions of the medium (e.g. air) through a microphone and storing the resulting data in a vector."

# ╔═╡ cfdabcf8-ebae-11ea-307a-7728476c9825
md"Jazmine, the teacher, sent Julia a [recording of a jazz song](https://freesound.org/s/37750/) ([cc0](https://creativecommons.org/publicdomain/zero/1.0/)), sampled 16,000 times per second:"

# ╔═╡ 49b7f3f4-eba7-11ea-14f1-31d09ab786bb
x = load("../data/jazz.ogg")

# ╔═╡ 0342bfec-ebc2-11ea-15a2-c769c8039d17
x_duration_seconds = length(x) / x.samplerate

# ╔═╡ c10ff5da-ebae-11ea-3205-6d1f6666ca5c
typeof(x), x.samplerate, length(x)

# ╔═╡ 6e4d19da-ebaf-11ea-113d-55eca1da0769
md"Each sample in $$x$$ corresponds to a microphone reading. The first 5 samples at $$1s$$ are:"

# ╔═╡ c7eccb4a-ebad-11ea-16f5-21299446a8a2
x[16_000:16_005, 1]

# ╔═╡ becebb5c-ebaf-11ea-3e5d-4f91c13b24a1
md"Plotting the audio wave:"

# ╔═╡ 3ab06516-eba5-11ea-2316-732fe86075f6
plot(domain(x), x[:, 1], xlabel="time (s)", ylabel="amplitude", title="Jazz song", linealpha=0.85, legend=false, linecolor=palette(:default)[2], fmt = :png, dpi=300)

# ╔═╡ c0e56d6e-ebb4-11ea-1250-d598737b4049
md"Julia, then danced against the same song and recorded herself near [the sea](https://freesound.org/s/9332/) ([cc-by-nc](https://creativecommons.org/licenses/by-nc/3.0/)):"

# ╔═╡ fdb90c24-ebb6-11ea-1a47-63001e2b8819
x2 = load("../data/jazz-waves.ogg")

# ╔═╡ 997f7a16-ed4a-11ea-3a29-891b059c3667
x2_duration_seconds = length(x2) / x2.samplerate

# ╔═╡ a3c0c930-ed4a-11ea-15e7-cb31b4e9675c
typeof(x2), x2.samplerate, length(x2)

# ╔═╡ 57466fbe-ed5a-11ea-2da0-199907c6bece
md"Let's look at Julia's audio wave:"

# ╔═╡ fba9972c-ebb4-11ea-2a8d-31350dd2855b
plot(domain(x2), x2[:, 1], xlabel="time (s)", ylabel="amplitude", title="Jazz song at the Sea", linealpha=0.85, legend=false, fmt = :png, dpi=300)

# ╔═╡ fa3508de-ed50-11ea-3357-19fd3a4b0441
md"We would like to know how much lag there is between the 2 different recordings of the same song: $$x$$ and $$x2$$."

# ╔═╡ b3997960-ebb0-11ea-2f91-af92117a47a2
md"## Using Cross Correlation to align audio signals"

# ╔═╡ fa4385a0-ebdc-11ea-2683-4107d5129e7e
md"Visually, we could superimpose both signals and slide each other over the time axis until they match as closely as possible. 

For example, take Jazmine's recording ($$x$$) and place it next to Julia's ($$x2$$). They are clearly not aligned."

# ╔═╡ 9701b1a8-ed51-11ea-3992-fb42d17e5d0f
begin
	x_right_padding_1 = zeros(Float32, length(x2) - length(x), 1)
	x_padded_1 = cat(x, x_right_padding_1, dims=1)
	mixed_1 = cat(x2, x_padded_1, dims=2)
	plot(domain(mixed_1), mixed_1, xlabel="time (s)", ylabel="amplitude", title="At the sea + Jazz song", linealpha=0.85, legend=false, fmt = :png, dpi=300)
end

# ╔═╡ 07457180-ed51-11ea-148b-5b8c40e3470f
md"Then slide Julia's recording ($$x2$$) $$0.1$$ seconds to the right, then again $$0.1$$ seconds, …

 $$1$$ second later:"

# ╔═╡ 2c083f2a-ed51-11ea-1884-33902424a474
begin
	x_left_padding_2 = zeros(Float32, convert(Int, 1 * x.samplerate), 1)
	x_right_padding_2 = zeros(Float32, length(x2) - length(x) - length(x_left_padding_2), 1)
	x_padded_2 = cat(x_left_padding_2, x, x_right_padding_2, dims=1)
	mixed_2 = cat(x2, x_padded_2, dims=2)
	plot(domain(mixed_2), mixed_2, xlabel="time (s)", ylabel="amplitude", title="At the sea + Jazz song. Offset 1 second", linealpha=0.85, legend=false, fmt = :png, dpi=300)
end

# ╔═╡ 05c3c5a0-ed56-11ea-24fd-2d6628bf80ba
md" $$2$$ seconds later:"

# ╔═╡ 2133853e-ed56-11ea-06a7-9bf1a022192c
begin
	x_left_padding_3 = zeros(Float32, convert(Int, 2 * x.samplerate), 1)
	x_right_padding_3 = zeros(Float32, length(x2) - length(x) - length(x_left_padding_3), 1)
	x_padded_3 = cat(x_left_padding_3, x, x_right_padding_3, dims=1)
	mixed_3 = cat(x2, x_padded_3, dims=2)
	plot(domain(mixed_2), mixed_3, xlabel="time (s)", ylabel="amplitude", title="At the sea + Jazz song. Offset 2 seconds", linealpha=0.85, legend=false, fmt = :png, dpi=300)
end

# ╔═╡ 5871916a-ed56-11ea-2db0-132308b8e7aa
md" $$2.5$$ seconds later both $$x$$ and $$x2$$ are perfectly aligned."

# ╔═╡ 594b2b64-ed56-11ea-104b-cbf7510a12b3
begin
	x_left_padding_4 = zeros(Float32, convert(Int, 2.5 * x.samplerate), 1)
	x_right_padding_4 = zeros(Float32, length(x2) - length(x) - length(x_left_padding_4), 1)
	x_padded_4 = cat(x_left_padding_4, x, x_right_padding_4, dims=1)
	mixed_4 = cat(x2, x_padded_4, dims=2)
	plot(domain(mixed_2), mixed_4, xlabel="time (s)", ylabel="amplitude", title="Ocean Wave + Jazz. Offset 2.5 seconds", linealpha=0.85, legend=false, fmt = :png, dpi=300)
end

# ╔═╡ 07e0ed2c-ed51-11ea-0dd4-cfca2a31506b
md"This sliding process is essentially what a cross-correlation measures. It tells us how similar 2 signals are when displaced relative to each other."

# ╔═╡ 1997e6ea-ebb1-11ea-0875-8ff96ec060dc
md"Mathematically, the [cross-correlation](https://en.wikipedia.org/wiki/Cross-correlation) of two temporal series $$u$$ and $$v$$ is defined as:"

# ╔═╡ 16b55988-ebb1-11ea-3b2b-6f432c3eb7d1
md"$$(u \star v)(t) \triangleq\ \int_{-\infty}^\infty \overline{u(\tau)} v(t + \tau) \, d\tau$$"

# ╔═╡ d4b1188e-ebb9-11ea-3487-bf00755dbd76
md"Where $$\overline{u(\tau)}$$ is the [complex conjugate](https://en.wikipedia.org/wiki/Complex_conjugate) of $$u(\tau)$$. And $$t$$ is the lag."

# ╔═╡ d8b9598a-ebb9-11ea-3f08-7d5e64c688b5
md"The cross-correlation ($$\star$$) of two functions is equivalent to the convolution ($$*$$) of one of the signals reversed in the time axis: 


$$(u \star v)(t) =  u(−t) ∗ g (t)$$

Moreover, the Fourier transform ($$\mathcal{F}$$) of a convolution [is equivalent](https://en.wikipedia.org/wiki/Convolution_theorem) to multiplying the Fourier tranforms of the functions:

$$\mathcal{F}\{u * v\} = \mathcal{F}\{u\} \cdot \mathcal{F}\{v\}$$

$$(u \star v)(t) = \mathcal{F}^{-1}\big\{\mathcal{F}\{u(-t)\}\cdot\mathcal{F}\{v(t)\}\big\}$$

As such we can [implement the cross-correlation](https://dsp.stackexchange.com/questions/736/how-do-i-implement-cross-correlation-to-prove-two-audio-files-are-similar) with the following steps:"

# ╔═╡ 2786714e-ebba-11ea-2f24-9f3640dd4b29
md"1. zero padding the signals and reversing one of them:"

# ╔═╡ 608c49d2-ebba-11ea-00ba-c541b8589037
begin
	x_max_size = abs(length(x2) - length(x))
	
	x_pad_size = length(x) + 2 * length(x_right_padding_1)
	x_pad = SampledSignals.SampleBuf(zeros(Float32, x_pad_size, 1), x.samplerate)
	x_padded = vcat(x, x_pad) 
	x_padded_reversed = reverse(x_padded, dims=1)
	
	x2_pad_size = length(x2)
	x2_pad = SampledSignals.SampleBuf(zeros(Float32, x2_pad_size, 1), x2.samplerate)
	x2_padded = vcat(x2, x2_pad)
	
	# Listen to this audio at 12 seconds. It is the same Jazz song (x) but reversed and with empty audio at the start
	x_padded_reversed
end

# ╔═╡ 6d193a4c-ebbb-11ea-2ba6-c1341160a063
md"2. Performing a convolution between both signals with their Fourier transforms: "

# ╔═╡ 5cbb311c-ebc2-11ea-3b5e-910d2b940555
convolution = irfft(rfft(x2_padded) .* rfft(x_padded_reversed), length(x_padded))

# ╔═╡ 7deba858-ebbb-11ea-2602-cffad18a927a
plot(domain(x2_padded), convolution[:, 1], xlabel="time (s)", ylabel="convolution(t)", legend=false, fmt = :png, dpi=300)

# ╔═╡ 25a1d500-ebbd-11ea-1c37-35974b7f928d
md"The point where the signals are most correlated corresponds to the peak of the convolution. This is the lag between $$x$$ and $$x2$$:"

# ╔═╡ 979fa4d2-ebbf-11ea-1139-b167cf216ac7
lag_index, peak_value = argmax(convolution[:, 1]), maximum(convolution[:, 1])

# ╔═╡ 7213820c-ebc3-11ea-3c87-d1dcb117d446
md"The lag is exactly 2.5 seconds. We can now use this value to align the audio/video files for Jazmine and Julia."

# ╔═╡ 8863e55c-ebc2-11ea-2495-a962207eacc0
lag_seconds = x_duration_seconds * lag_index / length(x)

# ╔═╡ Cell order:
# ╟─cf3ddc9c-ebab-11ea-1417-b7eb9e517b50
# ╟─2c57c0fe-ed5b-11ea-2837-81321cf21495
# ╟─34a5c400-ebd9-11ea-04cf-3118b3902453
# ╟─ae29c670-ebd9-11ea-3995-77063c4c3f4d
# ╟─eb4bd808-ebc9-11ea-3c71-e9850bb24137
# ╟─f7a9d13a-ebac-11ea-2abd-79345ce6fbef
# ╟─cfdabcf8-ebae-11ea-307a-7728476c9825
# ╟─b16a96ca-eba3-11ea-3a74-4fecb5dda838
# ╠═49b7f3f4-eba7-11ea-14f1-31d09ab786bb
# ╠═0342bfec-ebc2-11ea-15a2-c769c8039d17
# ╠═c10ff5da-ebae-11ea-3205-6d1f6666ca5c
# ╟─6e4d19da-ebaf-11ea-113d-55eca1da0769
# ╠═c7eccb4a-ebad-11ea-16f5-21299446a8a2
# ╟─becebb5c-ebaf-11ea-3e5d-4f91c13b24a1
# ╠═3ab06516-eba5-11ea-2316-732fe86075f6
# ╟─c0e56d6e-ebb4-11ea-1250-d598737b4049
# ╠═fdb90c24-ebb6-11ea-1a47-63001e2b8819
# ╠═997f7a16-ed4a-11ea-3a29-891b059c3667
# ╠═a3c0c930-ed4a-11ea-15e7-cb31b4e9675c
# ╟─57466fbe-ed5a-11ea-2da0-199907c6bece
# ╠═fba9972c-ebb4-11ea-2a8d-31350dd2855b
# ╟─fa3508de-ed50-11ea-3357-19fd3a4b0441
# ╟─b3997960-ebb0-11ea-2f91-af92117a47a2
# ╟─fa4385a0-ebdc-11ea-2683-4107d5129e7e
# ╟─9701b1a8-ed51-11ea-3992-fb42d17e5d0f
# ╟─07457180-ed51-11ea-148b-5b8c40e3470f
# ╟─2c083f2a-ed51-11ea-1884-33902424a474
# ╟─05c3c5a0-ed56-11ea-24fd-2d6628bf80ba
# ╟─2133853e-ed56-11ea-06a7-9bf1a022192c
# ╟─5871916a-ed56-11ea-2db0-132308b8e7aa
# ╟─594b2b64-ed56-11ea-104b-cbf7510a12b3
# ╟─07e0ed2c-ed51-11ea-0dd4-cfca2a31506b
# ╟─1997e6ea-ebb1-11ea-0875-8ff96ec060dc
# ╟─16b55988-ebb1-11ea-3b2b-6f432c3eb7d1
# ╟─d4b1188e-ebb9-11ea-3487-bf00755dbd76
# ╟─d8b9598a-ebb9-11ea-3f08-7d5e64c688b5
# ╟─2786714e-ebba-11ea-2f24-9f3640dd4b29
# ╠═608c49d2-ebba-11ea-00ba-c541b8589037
# ╟─6d193a4c-ebbb-11ea-2ba6-c1341160a063
# ╠═5cbb311c-ebc2-11ea-3b5e-910d2b940555
# ╠═7deba858-ebbb-11ea-2602-cffad18a927a
# ╟─25a1d500-ebbd-11ea-1c37-35974b7f928d
# ╠═979fa4d2-ebbf-11ea-1139-b167cf216ac7
# ╟─7213820c-ebc3-11ea-3c87-d1dcb117d446
# ╠═8863e55c-ebc2-11ea-2495-a962207eacc0
