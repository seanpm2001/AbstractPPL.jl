var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/#VarNames","page":"API","title":"VarNames","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"VarName\ngetsym\ngetoptic\ninspace\nsubsumes\nsubsumedby\nvsym\n@varname\n@vsym","category":"page"},{"location":"api/#AbstractPPL.VarName","page":"API","title":"AbstractPPL.VarName","text":"VarName{sym}(optic=identity)\n\nA variable identifier for a symbol sym and optic optic.\n\nThe Julia variable in the model corresponding to sym can refer to a single value or to a hierarchical array structure of univariate, multivariate or matrix variables. The field lens stores the indices requires to access the random variable from the Julia variable indicated by sym as a tuple of tuples. Each element of the tuple thereby contains the indices of one optic operation.\n\nVarNames can be manually constructed using the VarName{sym}(optic) constructor, or from an optic expression through the @varname convenience macro.\n\nExamples\n\njulia> vn = VarName{:x}(Accessors.IndexLens((Colon(), 1)) ⨟ Accessors.IndexLens((2, )))\nx[:, 1][2]\n\njulia> getoptic(vn)\n(@o _[Colon(), 1][2])\n\njulia> @varname x[:, 1][1+1]\nx[:, 1][2]\n\n\n\n\n\n","category":"type"},{"location":"api/#AbstractPPL.getsym","page":"API","title":"AbstractPPL.getsym","text":"getsym(vn::VarName)\n\nReturn the symbol of the Julia variable used to generate vn.\n\nExamples\n\njulia> getsym(@varname(x[1][2:3]))\n:x\n\njulia> getsym(@varname(y))\n:y\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.getoptic","page":"API","title":"AbstractPPL.getoptic","text":"getoptic(vn::VarName)\n\nReturn the optic of the Julia variable used to generate vn.\n\nExamples\n\njulia> getoptic(@varname(x[1][2:3]))\n(@o _[1][2:3])\n\njulia> getoptic(@varname(y))\nidentity (generic function with 1 method)\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.inspace","page":"API","title":"AbstractPPL.inspace","text":"inspace(vn::Union{VarName, Symbol}, space::Tuple)\n\nCheck whether vn's variable symbol is in space.  The empty tuple counts as the \"universal space\" containing all variables. Subsumption (see subsumes) is respected.\n\nExamples\n\njulia> inspace(@varname(x[1][2:3]), ())\ntrue\n\njulia> inspace(@varname(x[1][2:3]), (:x,))\ntrue\n\njulia> inspace(@varname(x[1][2:3]), (@varname(x),))\ntrue\n\njulia> inspace(@varname(x[1][2:3]), (@varname(x[1:10]), :y))\ntrue\n\njulia> inspace(@varname(x[1][2:3]), (@varname(x[:][2:4]), :y))\ntrue\n\njulia> inspace(@varname(x[1][2:3]), (@varname(x[1:10]),))\ntrue\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.subsumes","page":"API","title":"AbstractPPL.subsumes","text":"subsumes(u::VarName, v::VarName)\n\nCheck whether the variable name v describes a sub-range of the variable u.  Supported indexing:\n\nScalar:\n\n```jldoctest   julia> subsumes(@varname(x), @varname(x[1, 2]))   true\n\njulia> subsumes(@varname(x[1, 2]), @varname(x[1, 2][3]))   true   ```\n\nArray of scalar: basically everything that fulfills issubset.\n\n```jldoctest   julia> subsumes(@varname(x[[1, 2], 3]), @varname(x[1, 3]))   true\n\njulia> subsumes(@varname(x[1:3]), @varname(x[2][1]))   true   ```\n\nSlices:\n\njldoctest   julia> subsumes(@varname(x[2, :]), @varname(x[2, 10][1]))   true\n\nCurrently not supported are: \n\nBoolean indexing, literal CartesianIndex (these could be added, though)\nLinear indexing of multidimensional arrays: x[4] does not subsume x[2, 2] for a matrix x\nTrailing ones: x[2, 1] does not subsume x[2] for a vector x\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.subsumedby","page":"API","title":"AbstractPPL.subsumedby","text":"subsumedby(t, u)\n\nTrue if t is subsumed by u, i.e., if subsumes(u, t) is true.\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.vsym","page":"API","title":"AbstractPPL.vsym","text":"vsym(expr)\n\nReturn name part of the @varname-compatible expression expr as a symbol for input of the VarName constructor.\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.@varname","page":"API","title":"AbstractPPL.@varname","text":"@varname(expr, concretize=false)\n\nA macro that returns an instance of VarName given a symbol or indexing expression expr.\n\nIf concretize is true, the resulting expression will be wrapped in a concretize() call.\n\nNote that expressions involving dynamic indexing, i.e. begin and/or end, will always need to be concretized as VarName only supports non-dynamic indexing as determined by is_static_optic. See examples below.\n\nExamples\n\nDynamic indexing\n\njulia> x = (a = [1.0 2.0; 3.0 4.0; 5.0 6.0], );\n\njulia> @varname(x.a[1:end, end][:], true)\nx.a[1:3, 2][:]\n\njulia> @varname(x.a[end], false)  # disable concretization\nERROR: LoadError: Variable name `x.a[end]` is dynamic and requires concretization!\n[...]\n\njulia> @varname(x.a[end])  # concretization occurs by default if deemed necessary\nx.a[6]\n\njulia> # Note that \"dynamic\" here refers to usage of `begin` and/or `end`,\n       # _not_ \"information only available at runtime\", i.e. the following works.\n       [@varname(x.a[i]) for i = 1:length(x.a)][end]\nx.a[6]\n\njulia> # Potentially surprising behaviour, but this is equivalent to what Base does:\n       @varname(x[2:2:5]), 2:2:5\n(x[2:2:4], 2:2:4)\n\nGeneral indexing\n\nUnder the hood optics are used for the indexing:\n\njulia> getoptic(@varname(x))\nidentity (generic function with 1 method)\n\njulia> getoptic(@varname(x[1]))\n(@o _[1])\n\njulia> getoptic(@varname(x[:, 1]))\n(@o _[Colon(), 1])\n\njulia> getoptic(@varname(x[:, 1][2]))\n(@o _[Colon(), 1][2])\n\njulia> getoptic(@varname(x[1,2][1+5][45][3]))\n(@o _[1, 2][6][45][3])\n\nThis also means that we support property access:\n\njulia> getoptic(@varname(x.a))\n(@o _.a)\n\njulia> getoptic(@varname(x.a[1]))\n(@o _.a[1])\n\njulia> x = (a = [(b = rand(2), )], ); getoptic(@varname(x.a[1].b[end], true))\n(@o _.a[1].b[2])\n\nInterpolation can be used for variable names, or array name, but not the lhs of a . expression. Variables within indices are always evaluated in the calling scope.\n\njulia> name, i = :a, 10;\n\njulia> @varname(x.$name[i, i+1])\nx.a[10, 11]\n\njulia> @varname($name)\na\n\njulia> @varname($name[1])\na[1]\n\njulia> @varname($name.x[1])\na.x[1]\n\njulia> @varname(b.$name.x[1])\nb.a.x[1]\n\n\n\n\n\n","category":"macro"},{"location":"api/#AbstractPPL.@vsym","page":"API","title":"AbstractPPL.@vsym","text":"@vsym(expr)\n\nA macro that returns the variable symbol given the input variable expression expr. For example, @vsym x[1] returns :x.\n\nExamples\n\njulia> @vsym x\n:x\n\njulia> @vsym x[1,1][2,3]\n:x\n\njulia> @vsym x[end]\n:x\n\n\n\n\n\n","category":"macro"},{"location":"api/#Abstract-model-functions","page":"API","title":"Abstract model functions","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"AbstractProbabilisticProgram\ncondition\ndecondition\nlogdensityof\nAbstractContext\nevaluate!!","category":"page"},{"location":"api/#AbstractPPL.AbstractProbabilisticProgram","page":"API","title":"AbstractPPL.AbstractProbabilisticProgram","text":"AbstractProbabilisticProgram\n\nCommon base type for models expressed as probabilistic programs.\n\n\n\n\n\n","category":"type"},{"location":"api/#AbstractPPL.condition","page":"API","title":"AbstractPPL.condition","text":"condition(model, observations)\n\nCondition the generative model model on some observed data, creating a new model of the (possibly unnormalized) posterior distribution over them.\n\nobservations can be of any supported internal trace type, or a fixed probability expression.\n\nThe invariant \n\nm = decondition(condition(m, obs))\n\nshould hold for generative models m and arbitrary obs.\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.decondition","page":"API","title":"AbstractPPL.decondition","text":"decondition(conditioned_model)\n\nRemove the conditioning (i.e., observation data) from conditioned_model, turning it into a generative model over prior and observed variables.\n\nThe invariant \n\nm == condition(decondition(m), obs)\n\nshould hold for models m with conditioned variables obs.\n\n\n\n\n\n","category":"function"},{"location":"api/#DensityInterface.logdensityof","page":"API","title":"DensityInterface.logdensityof","text":"logdensityof(model, trace)\n\nEvaluate the (possibly unnormalized) density of the model specified by the probabilistic program in model, at specific values for the random variables given through trace.\n\ntrace can be of any supported internal trace type, or a fixed probability expression.\n\nlogdensityof should interact with conditioning and deconditioning in the way required by probability theory.\n\n\n\n\n\n","category":"function"},{"location":"api/#AbstractPPL.AbstractContext","page":"API","title":"AbstractPPL.AbstractContext","text":"AbstractContext\n\nCommon base type for evaluation contexts.\n\n\n\n\n\n","category":"type"},{"location":"api/#AbstractPPL.evaluate!!","page":"API","title":"AbstractPPL.evaluate!!","text":"evaluate!!\n\nGeneral API for model operations, e.g. prior evaluation, log density, log joint etc.\n\n\n\n\n\n","category":"function"},{"location":"api/#Abstract-traces","page":"API","title":"Abstract traces","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"AbstractModelTrace","category":"page"},{"location":"api/#AbstractPPL.AbstractModelTrace","page":"API","title":"AbstractPPL.AbstractModelTrace","text":"AbstractModelTrace\n\nCommon base class for various trace or \"variable info\" types.\n\n\n\n\n\n","category":"type"},{"location":"#AbstractPPL.jl","page":"Home","title":"AbstractPPL.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"A lightweight package containing interfaces and associated APIs for modelling languages for probabilistic programming.","category":"page"}]
}
