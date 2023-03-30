export Reconstruct, directreco

"""
        Reconstruct(acqd, sensit, noisemat)        

"""

# FUNCTION FOR SENSE RECONSTRUCTION
function Reconstruct(acqd::AcquisitionData,
                    sensit::Array{Complex{T},4},
                    noisemat::Union{Array{Complex{T}},Nothing} = nothing) where {T} 

    params = Dict{Symbol, Any}()
    params[:reco] = "multiCoil"
    params[:solver] = "cgnr"
    params[:regularization] = "L2"
    params[:λ] = 1.e-2
    params[:iterations] = 20
    params[:reconSize] = (acqd.encodingSize[1],acqd.encodingSize[2])
    params[:estimateProfileCenter] = true
    params[:senseMaps] = sensit
    if !isnothing(noisemat)
        params[:noiseData] = noisemat
    end
    # Do reconstruction
    img = reconstruction(acqd, params)
    img = dropdims(img, dims = tuple(findall(size(img) .== 1)...))
    return img
end


# FUNCTION TO RECONSTRUCT DATA DIRECTLY
function directreco(acq)

    params = Dict{Symbol, Any}()
    params[:reco] = "direct"
    params[:reconSize] = (acq.encodingSize[1],acq.encodingSize[2])

    return reconstruction(acq, params)

end