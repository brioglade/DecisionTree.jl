include("tree.jl")

# Convenience functions - make a Random Number Generator object
mk_rng(rng::AbstractRNG) = rng
mk_rng(seed::Int) = MersenneTwister(seed)

function build_stump{T<:Float64}(labels::Vector{T}, features::Matrix; rng=Base.GLOBAL_RNG)
    return build_tree(labels, features, 1, 0, 1)
end

function build_tree{T<:Float64}(
        labels::Vector{T}, features::Matrix, min_samples_leaf=5, n_subfeatures=0,
        max_depth=-1, min_samples_split=2, min_purity_increase=0.0;
        rng=Base.GLOBAL_RNG)
    rng = mk_rng(rng)::AbstractRNG
    if max_depth < -1
        error("Unexpected value for max_depth: $(max_depth) (expected: max_depth >= 0, or max_depth = -1 for infinite depth)")
    end
    if max_depth == -1
        max_depth = typemax(Int64)
    end
    if n_subfeatures == 0
        n_subfeatures = size(features, 2)
    end
    min_samples_leaf = Int64(min_samples_leaf)
    min_samples_split = Int64(min_samples_split)
    min_purity_increase = Float64(min_purity_increase)
    t = treeregressor.fit(
        features, labels, n_subfeatures, max_depth,
        min_samples_leaf, min_samples_split, min_purity_increase, 
        rng=rng)

    function _convert(node :: treeregressor.NodeMeta)
        if node.is_leaf
            return Leaf(node.label, node.labels)
        else
            left = _convert(node.l)
            right = _convert(node.r)
            return Node(node.feature, node.threshold, left, right)
        end
    end
    return _convert(t)
end

function build_forest{T<:Float64}(labels::Vector{T}, features::Matrix, n_subfeatures=0, n_trees=10, min_samples_leaf=5, partial_sampling=0.7, max_depth=-1; rng=Base.GLOBAL_RNG)
    rng = mk_rng(rng)::AbstractRNG
    partial_sampling = partial_sampling > 1.0 ? 1.0 : partial_sampling
    Nlabels = length(labels)
    Nsamples = _int(partial_sampling * Nlabels)
    forest = @parallel (vcat) for i in 1:n_trees
        inds = rand(rng, 1:Nlabels, Nsamples)
        build_tree(labels[inds], features[inds,:], min_samples_leaf, n_subfeatures, max_depth; rng=rng)
    end
    return Ensemble([forest;])
end
