# Turing + Makie -> Turkie!

WIP for an inference visualization package.

### To plot during sampling :
- [ ] Trace of the chains
- [ ] Statistics (mean and var)
- [ ] Marginals (KDE/Histograms)
- [ ] Autocorrelation plots

### Additional features :
- [ ] Selecting which variables are plotted
- [ ] Selecting what plots to show
- [ ] Giving a recording option
- [ ] Additional fine tuning features like
    - [ ] Thinning
    - [ ] Creating a buffer to limit the viewing

### Extra Features 
- [ ] Using a color mapping given some statistics
- [ ] Allow to apply transformation before plotting

## Usage:

Create a `TurViz` object:
```julia
TurViz() # default behavior : will plot the marginals of all variables
v= TurViz(a=:trace, b=:m_kde)
v = sample(model, sampler, n_iters, v)
```