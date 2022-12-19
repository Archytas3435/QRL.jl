### A Pluto.jl notebook ###
# v0.19.12

using Markdown
using InteractiveUtils

# ╔═╡ d3e3d00d-d100-43fc-81e7-99fece392cfc
begin
	ENV["PYTHON"] = "/Users/satvikduddukuru/Programming/Python/miniforge3/bin/python"
	using PyCall
	gym = pyimport("gym")
end

# ╔═╡ 2459b3b9-ce9e-4c5d-b66b-96dac1afb721
using Flux

# ╔═╡ 20f5af1b-e5a4-45b2-99e1-c2adc1f4688e
using Statistics

# ╔═╡ acf033ac-7c85-11ed-3b94-69cf6b92312b
html"""
<style>
	main {
		margin: 0 auto;
		max-width: 2000px;
    	padding-left: max(10px, 10%);
    	padding-right: max(10px, 10%);
	}
</style>
"""

# ╔═╡ 98ab6bc6-9dd9-4282-b886-6318709fd5a5
begin
	import LinearAlgebra: kron, det, I
	kron(U::Matrix{ComplexF64}) = U
end

# ╔═╡ 744a2348-157c-490e-8489-247d470b6b8a
verify_magnitude_sum(zs::Number...) = sum((z->abs(z)^2).(zs)) ≈ 1

# ╔═╡ d960b142-d90d-48c4-8b73-08c2b87776a7
import Latexify: latexify

# ╔═╡ 2961fa90-b4d9-4b9b-a2b7-de921f1b9113
begin
	# representations of a qubit and its properties
	struct Qubit
		# |Ψ⟩ = α|0⟩ + β|1⟩
		# |α|² + |β|² = 1
		α::Complex
		β::Complex
		Qubit() = new(1, 0)
		Qubit(α::ComplexF64, β::ComplexF64) = verify_magnitude_sum(α, β) ? new(α, β) : error("Invalid Probability Amplitudes")
		Qubit(θ::Real, ϕ::Real) = new(cos((π*θ/180)/2)+0.0im, exp(im*(π*ϕ/180))*sin((π*θ/180)/2)+0.0im)
		Qubit(v::Matrix{ComplexF64}) = new(v[1:2]...)
	end
	qubit_vector(q::Qubit)::Matrix = convert.(ComplexF64, reshape([q.α, q.β], (2, 1)))
	multi_qubit_vector(qs::Qubit...)::Matrix = kron(qubit_vector.(qs)...)	
	struct NQubit{N}
		# |ψ⟩ = ∑ᵢαᵢ|bin(i)⟩
		# ∑ᵢ|αᵢ|² = 1
		coefficients::Matrix{ComplexF64}
		NQubit(qubits::Qubit...) = length(qubits)>1 ? new{length(qubits)}(multi_qubit_vector(qubits...)) : new{length(qubits)}(qubit_vector(qubits[1]))
		NQubit(qubits::Matrix{ComplexF64}) = new{length(qubits)}(qubits)
	end
	custom_round(ψ::NQubit) = NQubit(custom_round.(ψ.coefficients))
	
	import Base: *
	a::Matrix{ComplexF64} * q::Qubit = Qubit(a * convert.(ComplexF64, reshape([q.α, q.β], (2, 1))))
	a::Matrix{ComplexF64} * q::NQubit = NQubit(a * q.coefficients)
end

# ╔═╡ 991c8373-9669-4658-bbf2-272e0a130a95
custom_round(z, n_digits=10) = round(real(z), digits=n_digits) + round(imag(z), digits=n_digits)*im

# ╔═╡ 35a3256c-c541-466d-ac2e-e8c37d696c14
begin
	# nice way to see the wave equation
	linear_superposition_representation(ψ::Matrix) = join(["($(custom_round(ψ[i])))|$(lpad(string(i-1, base=2), Int(log2(length(ψ))), "0"))⟩" for i in 1:length(ψ)], " + ")
	linear_superposition_representation(ψ::NQubit) = linear_superposition_representation(ψ.coefficients)
	coefficients_probabilities(ψ::Matrix) = [
		["|$(lpad(string(i-1, base=2), Int(log2(length(ψ))), "0"))⟩" for i in 1:length(ψ)],
		["$(custom_round(ψ[i]))" for i in 1:length(ψ)],
		["$(round(abs2(ψ[i]), digits=10))" for i in 1:length(ψ)]
	]
	coefficients_probabilities(ψ::NQubit) = coefficients_probabilities(ψ.coefficients)
end

# ╔═╡ 812ea7ec-3897-4f76-9766-050f651149d9
begin
	# nice way to see collapsed states
	probabilities(ψ::Matrix) = round.(ψ, digits=5), probabilities_only(ψ)
	probabilities(ψ::NQubit) = probabilities(ψ.coefficients)
	probabilities_only(ψ::Matrix) = vcat(["|$(lpad(string(i-1, base=2), Int(log2(length(ψ))), "0"))⟩: $(round(abs(ψ[i])^2, digits=5))" for i in 1:length(ψ)]...)
	probabilities_only(ψ::NQubit) = probabilities_only(ψ.coefficients)
end

# ╔═╡ bafd494a-5444-4eee-a710-b66b9a249a71
begin
	
	# 1-qubit gates
	R_x(θ::Real)::Matrix{ComplexF64} = [cos((π*θ/180)/2) -im*sin((π*θ/180)/2); -im*sin((π*θ/180)/2) cos((π*θ/180)/2)]
	R_y(θ::Real)::Matrix{ComplexF64} = [cos((π*θ/180)/2) -sin((π*θ/180)/2); sin((π*θ/180)/2) cos((π*θ/180)/2)]
	R_z(θ::Real)::Matrix{ComplexF64} = [exp(-im*(π*θ/180)/2) 0; 0 exp(im*(π*θ/180)/2)]
	P(λ)::Matrix{ComplexF64} = [1 0; 0 exp(im*λ)]
	H = Matrix{ComplexF64}([1/√(2) 1/√(2); 1/√(2) -1/√(2)])
	X = Matrix{ComplexF64}([0 1; 1 0])
	Y = Matrix{ComplexF64}([0 -im; im 0])
	Z = Matrix{ComplexF64}([1 0; 0 -1])
	S = Matrix{ComplexF64}([1 0; 0 im])
	T = Matrix{ComplexF64}([1 0; 0 sqrt(im)])
	decompose(U::Matrix{ComplexF64}) = begin
		γ = atan(imag(det(U)),real(det(U)))/2
		V = exp(-im*γ)*U
		θ = abs(V[1, 1])≥abs(V[1, 2]) ? 2*acos(abs(V[1, 1])) : 2*asin(abs(V[1, 2]))
		if cos(θ/2) == 0
			λ = atan(imag(V[2, 1]/sin(θ/2)), real(V[2, 1]/sin(θ/2)))
			ϕ = -λ
		elseif sin(θ/2) == 0
			ϕ = atan(imag(V[2, 2]/cos(θ/2)), real(V[2, 2]/cos(θ/2)))
			λ = ϕ
		else
			ϕ = atan(imag(V[2, 2]/cos(θ/2)), real(V[2, 2]/cos(θ/2)))+atan(imag(V[2, 1]/sin(θ/2)), real(V[2, 1]/sin(θ/2)))
			λ = 2*atan(imag(V[2, 2]/cos(θ/2)), real(V[2, 2]/cos(θ/2)))-ϕ
		end
		(
			round(rad2deg(real(θ)), digits=5), 
			round(rad2deg(real(ϕ)), digits=5), 
			round(rad2deg(real(λ)), digits=5),
			round(rad2deg(real(γ)), digits=5)
		)
	end
	U₃(θ, ϕ, λ, γ) = custom_round.(exp(im*(π*γ/180))*(R_z(ϕ)*R_y(θ)*R_z(λ)))

	# 2-qubit gates
	CU(num_registers::Int, U::Matrix{ComplexF64}, control_index::Int, target_index::Int) = 
		target_index > control_index ? kron(
			I(2^(control_index-1)), 
			[1, 0] * [1 0], 
			I(2^(num_registers-control_index))
		) + kron(
			I(2^(control_index-1)), 
			[0, 1] * [0 1], 
			I(2^(target_index-control_index-1)), 
			U, 
			I(2^(num_registers-target_index))
		) : kron(
			I(2^(control_index-1)), 
			[1, 0] * [1 0], 
			I(2^(num_registers-control_index))
		) + kron(
			I(2^(target_index-1)),
			U,
			I(2^(control_index-target_index-1)), 
			[0, 1] * [0 1], 
			I(2^(num_registers-control_index))
		)
	CX = CU(2, X, 2, 1)
	CZ = CU(2, Z, 2, 1)
	CS = CU(2, S, 2, 1)
	CH = CU(2, H, 2, 1)
	SWAP = Matrix{ComplexF64}([1 0 0 0; 0 0 1 0; 0 1 0 0; 0 0 0 1])

	# 3-qubit gates
	CCU(num_registers::Int, U::Matrix{ComplexF64}, control_index_1::Int, control_index_2::Int, target_index::Int) = 
		target_index > min(control_index_1, control_index_2) ? kron(
			I(2^(min(control_index_1, control_index_2)-1)), 
			[1, 0] * [1 0], 
			I(2^(num_registers-min(control_index_1, control_index_2)))
		) + kron(
			I(2^(min(control_index_1, control_index_2)-1)), 
			[0, 1] * [0 1], 
			CU(num_registers-min(control_index_1, control_index_2), U, target_index-min(control_index_1, control_index_2), max(control_index_1, control_index_2)-min(control_index_1, control_index_2))
		) : kron(
			I(2^(max(control_index_1, control_index_2)-1)), 
			[1, 0] * [1 0], 
			I(2^(num_registers-max(control_index_1, control_index_2)))
		) + kron(
			CU(max(control_index_1, control_index_2)-1, U, target_index, min(control_index_1, control_index_2)),
			[0, 1] * [0 1],
			I(2^(num_registers-max(control_index_1, control_index_2)))
		)
	CB(B::Matrix{ComplexF64})::Matrix{ComplexF64} = hvcat(
		(2, 2),
		[1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1],
		[0 0 0 0; 0 0 0 0; 0 0 0 0; 0 0 0 0],
		[0 0 0 0; 0 0 0 0; 0 0 0 0; 0 0 0 0],
		B
	)
	CCX = CCU(3, X, 1, 2, 3)
	CSWAP = CB(SWAP)

	# N-qubit gates
	COLUMN(I_before::Int, gate::Matrix{ComplexF64}, I_after::Int) = kron(
		I(2^I_before),
		gate,
		I(2^I_after)
	)
	QFT(N::Int) = custom_round.([exp(2*i*j*π*im/(2^N))/sqrt(2^N) for i in 0:2^N-1, j in 0:2^N-1])
	IQFT(N::Int) = adjoint(QFT(N))
	NSWAP(a::Int, b::Int, N::Int) = begin
		# move register A to register B in an N-Qubit system
		U = kron((Iₙ(2) for i in 1:N)...)
		for i in 1:abs(b-a)
			U = kron((Iₙ(2) for j in 1:(b>a ? a+i-2 : a-i-1))..., SWAP, (Iₙ(2) for j in (b>a ? a+i+1 : a-i+2):N)...) * U
		end
		U
	end
	ENTANGLING_LAYER(N::Int) = N == 2 ? CZ : *((CU(N, Z, 1, N), (CU(N, Z, i, i+1) for i in 1:N-1)...)...)
	
end

# ╔═╡ 9f03c2ea-811f-494c-b4d7-4ce7d804bd23
begin
	struct Circuit{N}
		ψ::NQubit{N}
		columns::Array{Matrix{ComplexF64}}
		Circuit(N::Int) = new{N}(NQubit((Qubit() for i in 1:N)...), [])
		Circuit(N::Int, columns::Array{Matrix{ComplexF64}}) = new{N}(NQubit((Qubit() for i in 1:N)...), columns)
		Circuit(qubits::Qubit...) = new{length(qubits)}(NQubit(qubits...), [])
		Circuit(ψ::NQubit) = new{typeof(ψ).parameters[1]}(ψ, [])
		Circuit(ψ::NQubit, columns::Array{Matrix{ComplexF64}}) = new{typeof(ψ).parameters[1]}(ψ, columns)
	end
	
	add_gate(C::Circuit, column::Int, gate::Matrix{ComplexF64}) = column ≤ length(c.columns) ? 	insert!(C.columns, column, gate) : begin
			resize!(C.columns, column) 
			insert!(C.columns, column, gate)
		end

	run(C::Circuit) = begin
		columns = [C.columns[i] for i in 1:length(C.columns) if isassigned(C.columns, i)]
		ψ = C.ψ
		for c in columns
			ψ = c * ψ
		end
		ψ
	end
end

# ╔═╡ daf136d6-a2a2-476a-b89b-1d575a2fee46
begin
	struct ReUploadingPQC
	end

	call(R::ReUploadingPQC, inputs) = begin
	end
end

# ╔═╡ 2c0996bf-d6d1-47f7-8177-625018bab228
begin
	struct Alternating
		w::Matrix
		Alternating(n_dim) = new(
			[(-1)^(i-1) for i in 1:output_dim]
		)
	end

	call(A::Alternating, inputs) = begin
		*(inputs..., A.w)
	end
end

# ╔═╡ 660ea9dc-4c64-45e6-87cb-0fe63aa7344e
begin
	generate_model_policy() = begin
	end

	gather_episodes() = begin
	end

	compute_returns() = begin
	end

	reinforce_update() = begin
	end
end

# ╔═╡ d00a44fe-040f-4fb8-a57f-ee025a36a452
begin
	n_qubits = 4
	n_layers = 5
	n_actions = 2
	state_bounds = [2.4, 2.5, .21, 2.5]
	gamma = 1
	batch_size = 10
	n_episodes = 1000
	optimizer_in = Adam(0.1)
	optimizer_var = Adam(0.01)
	optimizer_out = Adam(0.1)
	w_in, w_var, w_out = 1, 0, 2
end

# ╔═╡ 4a497f16-7202-487e-a129-26d5b925e64c
gym.make("CartPole-v1")

# ╔═╡ a992fa2a-5062-4043-8e48-45d5d3b7f515


# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Flux = "~0.13.9"
Latexify = "~0.15.17"
PyCall = "~1.94.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc3"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[deps.Accessors]]
deps = ["Compat", "CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Requires", "Test"]
git-tree-sha1 = "eb7a1342ff77f4f9b6552605f27fd432745a53a3"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.22"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random", "Test"]
git-tree-sha1 = "a598ecb0d717092b5539dbbe890c98bac842b072"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.2.0"

[[deps.BangBang]]
deps = ["Compat", "ConstructionBase", "Future", "InitialValues", "LinearAlgebra", "Requires", "Setfield", "Tables", "ZygoteRules"]
git-tree-sha1 = "7fe6d92c4f281cf4ca6f2fba0ce7b299742da7ca"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.3.37"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CUDA]]
deps = ["AbstractFFTs", "Adapt", "BFloat16s", "CEnum", "CompilerSupportLibraries_jll", "ExprTools", "GPUArrays", "GPUCompiler", "LLVM", "LazyArtifacts", "Libdl", "LinearAlgebra", "Logging", "Printf", "Random", "Random123", "RandomNumbers", "Reexport", "Requires", "SparseArrays", "SpecialFunctions", "TimerOutputs"]
git-tree-sha1 = "49549e2c28ffb9cc77b3689dc10e46e6271e9452"
uuid = "052768ef-5323-5732-b1bb-66c8b64840ba"
version = "3.12.0"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "Statistics", "StructArrays"]
git-tree-sha1 = "0c8c8887763f42583e1206ee35413a43c91e2623"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.45.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e7ff6cadf743c098e08fca25c91103ee4303c9bb"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.6"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "00a2cccc7f098ff3b66806862d275ca3db9e6e5a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.5.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.CompositionsBase]]
git-tree-sha1 = "455419f7e328a1a2493cabc6428d79e951349769"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.1"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "6e47d11ea2776bc5627421d59cdcc1296c058071"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.7.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "fb21ddd70a051d882a1686a5a550990bbe371a95"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.1"

[[deps.ContextVariablesX]]
deps = ["Compat", "Logging", "UUIDs"]
git-tree-sha1 = "25cc3803f1030ab855e383129dcd3dc294e322cc"
uuid = "6add18c4-b38d-439d-96f6-d6bc489c04c5"
version = "0.1.3"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "c5b6685d53f933c11404a3ae9822afe30d522494"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.12.2"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.FLoops]]
deps = ["BangBang", "Compat", "FLoopsBase", "InitialValues", "JuliaVariables", "MLStyle", "Serialization", "Setfield", "Transducers"]
git-tree-sha1 = "ffb97765602e3cbe59a0589d237bf07f245a8576"
uuid = "cc61a311-1640-44b5-9fba-1b764f453329"
version = "0.2.1"

[[deps.FLoopsBase]]
deps = ["ContextVariablesX"]
git-tree-sha1 = "656f7a6859be8673bf1f35da5670246b923964f7"
uuid = "b9860ae5-e623-471e-878b-f6a53c775ea6"
version = "0.1.1"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "9a0472ec2f5409db243160a8b030f94c380167a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.6"

[[deps.Flux]]
deps = ["Adapt", "CUDA", "ChainRulesCore", "Functors", "LinearAlgebra", "MLUtils", "MacroTools", "NNlib", "NNlibCUDA", "OneHotArrays", "Optimisers", "ProgressLogging", "Random", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "Zygote"]
git-tree-sha1 = "2b85cb85f5d71f05e41089a2446ac33b8e94ebed"
uuid = "587475ba-b771-5e3f-ad9e-33799f191a9c"
version = "0.13.9"

[[deps.FoldsThreads]]
deps = ["Accessors", "FunctionWrappers", "InitialValues", "SplittablesBase", "Transducers"]
git-tree-sha1 = "eb8e1989b9028f7e0985b4268dabe94682249025"
uuid = "9c68100b-dfe1-47cf-94c8-95104e173443"
version = "0.1.1"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "a69dd6db8a809f78846ff259298678f0d6212180"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.34"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "993c2b4a9a54496b6d8e265db1244db418f37e01"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.1"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GPUArrays]]
deps = ["Adapt", "GPUArraysCore", "LLVM", "LinearAlgebra", "Printf", "Random", "Reexport", "Serialization", "Statistics"]
git-tree-sha1 = "45d7deaf05cbb44116ba785d147c518ab46352d7"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "8.5.0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "6872f5ec8fd1a38880f027a26739d42dcda6691f"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.2"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "30488903139ebf4c88f965e7e396f2d652f988ac"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.16.7"

[[deps.IRTools]]
deps = ["InteractiveUtils", "MacroTools", "Test"]
git-tree-sha1 = "2e99184fca5eb6f075944b04c22edec29beb4778"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.7"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JuliaVariables]]
deps = ["MLStyle", "NameResolution"]
git-tree-sha1 = "49fb3cb53362ddadb4415e9b73926d6b40709e70"
uuid = "b14d175d-62b4-44ba-8fb7-3064adc8c3ec"
version = "0.2.4"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Printf", "Unicode"]
git-tree-sha1 = "088dd02b2797f0233d92583562ab669de8517fd1"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "4.14.1"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg", "TOML"]
git-tree-sha1 = "771bfe376249626d3ca12bcd58ba243d3f961576"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.16+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "ab9aa169d2160129beb241cb2750ca499b4e90e9"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.17"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "946607f84feb96220f480e0422d3484c49c00239"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.19"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MLStyle]]
git-tree-sha1 = "060ef7956fef2dc06b0e63b294f7dbfbcbdc7ea2"
uuid = "d8e11817-5142-5d16-987a-aa16d5891078"
version = "0.4.16"

[[deps.MLUtils]]
deps = ["ChainRulesCore", "DataAPI", "DelimitedFiles", "FLoops", "FoldsThreads", "NNlib", "Random", "ShowCases", "SimpleTraits", "Statistics", "StatsBase", "Tables", "Transducers"]
git-tree-sha1 = "82c1104919d664ab1024663ad851701415300c5f"
uuid = "f1d291b0-491e-4a28-83b9-f70985020b54"
version = "0.3.1"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.MicroCollections]]
deps = ["BangBang", "InitialValues", "Setfield"]
git-tree-sha1 = "4d5917a26ca33c66c8e5ca3247bd163624d35493"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.1.3"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NNlib]]
deps = ["Adapt", "ChainRulesCore", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "37596c26f107f2fd93818166ed3dab1a2e6b2f05"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.8.11"

[[deps.NNlibCUDA]]
deps = ["Adapt", "CUDA", "LinearAlgebra", "NNlib", "Random", "Statistics"]
git-tree-sha1 = "4429261364c5ea5b7308aecaa10e803ace101631"
uuid = "a00861dc-f156-4864-bf3c-e6376f28a68d"
version = "0.2.4"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NameResolution]]
deps = ["PrettyPrint"]
git-tree-sha1 = "1a0fa0e9613f46c9b8c11eee38ebb4f590013c5e"
uuid = "71a1bf82-56d0-4bbc-8a3c-48b961074391"
version = "0.1.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OneHotArrays]]
deps = ["Adapt", "ChainRulesCore", "Compat", "GPUArraysCore", "LinearAlgebra", "NNlib"]
git-tree-sha1 = "97af68a840d83df94053f45e68b944e645a2262c"
uuid = "0b1bfda6-eb8a-41d2-88d8-f5af5cad476f"
version = "0.2.1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optimisers]]
deps = ["ChainRulesCore", "Functors", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "e657acef119cc0de2a8c0762666d3b64727b053b"
uuid = "3bd65402-5787-11e9-1adc-39752487f4e2"
version = "0.2.14"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "6466e524967496866901a78fca3f2e9ea445a559"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyPrint]]
git-tree-sha1 = "632eb4abab3449ab30c5e1afaa874f0b98b586e4"
uuid = "8162dcfd-2161-5ef2-ae6c-7681170c5f98"
version = "0.2.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "53b8b07b721b77144a0fbbbc2675222ebf40a02d"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.94.1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "7a1a306b72cfa60634f03a911405f4e64d1b718b"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.6.0"

[[deps.RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.ShowCases]]
git-tree-sha1 = "7f534ad62ab2bd48591bdeac81994ea8c445e4a5"
uuid = "605ecd9f-84a6-4c9e-81e2-4798472b76a3"
version = "0.1.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SnoopPrecompile]]
git-tree-sha1 = "f604441450a3c0569830946e5b33b78c928e1a85"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.1"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "ffc098086f35909741f71ce21d03dadf0d2bfa76"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.11"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "b03a3b745aa49b566f128977a7dd1be8711c5e71"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.14"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "c79322d36826aa2f4fd8ecfa96ddb47b174ac78d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "f2fd3f288dfc6f507b0c3a2eb3bac009251e548b"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.22"

[[deps.Transducers]]
deps = ["Adapt", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "Setfield", "SplittablesBase", "Tables"]
git-tree-sha1 = "c42fa452a60f022e9e087823b47e5a5f8adc53d5"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.75"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "GPUArrays", "GPUArraysCore", "IRTools", "InteractiveUtils", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NaNMath", "Random", "Requires", "SparseArrays", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "a6f1287943ac05fae56fa06049d1a7846dfbc65f"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.51"

[[deps.ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─acf033ac-7c85-11ed-3b94-69cf6b92312b
# ╠═d3e3d00d-d100-43fc-81e7-99fece392cfc
# ╠═2459b3b9-ce9e-4c5d-b66b-96dac1afb721
# ╠═98ab6bc6-9dd9-4282-b886-6318709fd5a5
# ╠═20f5af1b-e5a4-45b2-99e1-c2adc1f4688e
# ╠═744a2348-157c-490e-8489-247d470b6b8a
# ╠═d960b142-d90d-48c4-8b73-08c2b87776a7
# ╠═2961fa90-b4d9-4b9b-a2b7-de921f1b9113
# ╠═991c8373-9669-4658-bbf2-272e0a130a95
# ╠═35a3256c-c541-466d-ac2e-e8c37d696c14
# ╠═812ea7ec-3897-4f76-9766-050f651149d9
# ╠═bafd494a-5444-4eee-a710-b66b9a249a71
# ╠═9f03c2ea-811f-494c-b4d7-4ce7d804bd23
# ╠═daf136d6-a2a2-476a-b89b-1d575a2fee46
# ╠═2c0996bf-d6d1-47f7-8177-625018bab228
# ╠═660ea9dc-4c64-45e6-87cb-0fe63aa7344e
# ╠═d00a44fe-040f-4fb8-a57f-ee025a36a452
# ╠═4a497f16-7202-487e-a129-26d5b925e64c
# ╠═a992fa2a-5062-4043-8e48-45d5d3b7f515
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
