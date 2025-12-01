# Build

We use [Franklin.jl](https://github.com/JuliaDocs/Franklin.jl.git) to build this site. On
the root of the repository, run:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); using Franklin; Franklin.serve();'
```

This will start a local server at `http://localhost:8000` where you can preview the site.
