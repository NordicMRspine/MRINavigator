export OrderSlices!, ExtractNoiseData!, ReverseBipolar!, RemoveRef!, CopyTE!, AdjustSubsampleIndices!, ExtractNavigator

"""
    OrderSlices!(rawData::RawAcquisitionData)

Spatially order the slices in the raw data structure.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
"""
function OrderSlices!(rawData::RawAcquisitionData)

    total_num = length(rawData.profiles)
    slices = zeros(typeof(rawData.profiles[1].head.position[3]), total_num)

    for ii = 1:total_num
        slices[ii] = rawData.profiles[ii].head.position[3]
    end

    unique!(slices)
    slices_indx = sortperm(sortperm(slices))

    for ii = 1:total_num
        index = rawData.profiles[ii].head.position[3] .== slices
        rawData.profiles[ii].head.idx.slice = slices_indx[index][1]-1
    end

end


"""
    flags = ExtractFlags(rawData::RawAcquisitionData) 

Extract the acquisition flags from raw data profiles.
Return a 31 elements vector for each profile.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
"""
function ExtractFlags(rawData::RawAcquisitionData)

    total_num = length(rawData.profiles)
    flags = zeros(Int64, total_num, 31)

    for ii=1:total_num
        flags[ii,:] = digits(rawData.profiles[ii].head.flags, base = 2, pad=31)
    end

    return flags

end


"""
    noisemat = ExtractNoiseData!(rawData::RawAcquisitionData, flags::Array{Int64})

Extract and return the noise acquisition from the raw data.
The noise acquisition is one of the profiles with slice = 0, contrast = 0, repetition = 0.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
"""
function ExtractNoiseData!(rawData::RawAcquisitionData)

    flags = ExtractFlags(rawData)
    total_num = length(rawData.profiles)
    if total_num != size(flags, 1)
        @error "size of flags and number of profiles in rawData do not match"
    end
    noisemat = Matrix{typeof(rawData.profiles[1].data)}

    for ii=1:total_num

        if flags[ii,19] == true
            noisemat = rawData.profiles[ii].data
            deleteat!(rawData.profiles, ii)
            break
        end

    end

    return noisemat

end


"""
    ReverseBipolar!(rawData::RawAcquisitionData)

Reflect the raw data profiles for bipolar acquisition.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
"""
function ReverseBipolar!(rawData::RawAcquisitionData)

    flags = ExtractFlags(rawData)
    total_num = length(rawData.profiles)
    if total_num != size(flags, 1)
        @error "size of flags and number of profiles in rawData do not match"
    end

    for ii=1:total_num

        if flags[ii,22] == true
            reverse!(rawData.profiles[ii].data, dims=1)
            rawData.profiles[ii].head.flags=rawData.profiles[ii].head.flags-(2^21)
        end

    end

end


"""
    RemoveRef!(rawData::RawAcquisitionData, slices::Union{Vector{Int64}, Nothing}, echoes::Union{Vector{Int64}, Nothing})

Remove reference data that are acquired with the phase stabilization on Siemens scanners.
Not solid to recalls.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
* `slices::Union{Vector{Int64}, Nothing}` - vector containing the numbers of slices to be loaded with MRIReco.jl. Nothing loads all.
* `echoes::Union{Vector{Int64}, Nothing}` - vector containing the numbers of echoes to be loaded with MRIReco.jl. Nothing loads all.
"""
function RemoveRef!(rawData::RawAcquisitionData, slices::Union{Vector{Int64}, Nothing}, echoes::Union{Vector{Int64}, Nothing})

    numSlices = 0
    numEchoes = 0
    if slices === nothing
        numSlices = rawData.params["enc_lim_slice"].maximum+1
    else
        numSlices = size(slices, 1)
    end
    if echoes !== nothing
        if 0 in echoes
            numEchoes = size(echoes, 1) +1 # the navigator is saved as echo zero
        else
            numEchoes = size(echoes, 1)
        end
    else
        numEchoes = size(rawData.params["TE"],1)+1
    end

    #Apply this only if using phase stabilizaion
    removeIndx = numSlices*(numEchoes)
    deleteat!(rawData.profiles, 1:removeIndx)

end


"""
    CopyTE!(rawData::RawAcquisitionData, acqData::AcquisitionData)

Copy the TE values from the raw data structor to the acquisition data structor.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
* `acqData::RawAcquisitionData` - acquisition data structure obtained converting raw data with MRIReco.jl
"""
function CopyTE!(rawData::RawAcquisitionData, acqData::AcquisitionData)

    for ii=1:size(acqData.kdata)[1]
        acqData.traj[ii].TE = rawData.params["TE"][ii]
    end

end


"""
    AdjustSubsampleIndices!(acqData::AcquisitionData)

Add subsamples indices in the acquisition data structure.
Needed when conveting data not acquired at the first repetition.

# Arguments
* `acqData::RawAcquisitionData` - acquisition data structure obtained converting raw data with MRIReco.jl
"""
function AdjustSubsampleIndices!(acqData::AcquisitionData)

    if isempty(acqData.subsampleIndices[1])
        for ii = 1:size(acqData.subsampleIndices)[1]
            acqData.subsampleIndices[ii]=1:size(acqData.kdata[1,1,1])[1]
        end
    end

end


"""
    (nav, nav_time) = ExtractNavigator(rawData::RawAcquisitionData, slices::Union{Vector{Int64}, Nothing})

Extract the navigator profiles from the raw data structure.
These are registered with the same indices as the image data for the first echo time.

# Arguments
* `rawData::RawAcquisitionData` - raw data structure obtained loading raw data with MRIReco.jl
* `slices::Union{Vector{Int64}, Nothing}` - vector containing the numbers of the slices that were loaded with MRIReco.jl
"""
function ExtractNavigator(rawData::RawAcquisitionData, slices::Union{Vector{Int64}, Nothing})

    total_num = length(rawData.profiles)
    numberslices = 0
    if isnothing(slices)
        numberslices = rawData.params["enc_lim_slice"].maximum +1
    else
        numberslices = size(slices,1)
    end
    contrasts = zeros(Int64, total_num)
    slices = zeros(Int64, total_num)
    lines = zeros(Int64, total_num)
    for ii = 1:total_num
        contrasts[ii] = rawData.profiles[ii].head.idx.contrast
        slices[ii] = rawData.profiles[ii].head.idx.slice
        lines[ii] = rawData.profiles[ii].head.idx.kspace_encode_step_1
    end
    # keep only the indexes of data saved in the first echo (this includes navigator)
    contrastsIndx = findall(x->x==0, contrasts)
    slices = slices[contrastsIndx]
    lines = lines[contrastsIndx]

    nav = zeros(ComplexF32, size(rawData.profiles[1].data)[1], size(rawData.profiles[1].data)[2],
        rawData.params["reconSize"][2], numberslices)

    nav_time = zeros(Float64,
        rawData.params["reconSize"][2], numberslices)
    #Odd indexes are data first echo, Even indexes are navigator data
    for ii = 2:2:length(slices)
        nav[:,:,lines[ii]+1,slices[ii]+1] = rawData.profiles[contrastsIndx[ii]].data
        nav_time[lines[ii]+1,slices[ii]+1] = rawData.profiles[contrastsIndx[ii]].head.acquisition_time_stamp
    end
    #Remove the rows filled with zeroes
    lines = unique(lines) .+1
    nav = nav[:,:,lines,:]
    nav_time = nav_time[lines,:]

    return nav, nav_time
    #navigator[k-space samples, coils, k-space lines, slices]

end