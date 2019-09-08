

module MountainCarExperiment

using DeepRL
using Flux
using Random
using ProgressMeter
using Plots
using TensorBoardLogger
using Logging
using LinearAlgebra

glorot_uniform(rng::Random.AbstractRNG, dims...) = (rand(rng, Float32, dims...) .- 0.5f0) .* sqrt(24.0f0/sum(dims))
glorot_normal(rng::Random.AbstractRNG, dims...) = randn(rng, Float32, dims...) .* sqrt(2.0f0/sum(dims))


function construct_agent(s, num_actions)
    
    ϵ=0.1
    γ=1.0f0
    batch_size=32
    tn_counter_init=50

    model = Chain(Dense(length(s), 128, Flux.relu; initW=Flux.glorot_uniform),
                  Dense(128, 128, Flux.relu; initW=Flux.glorot_uniform),
                  Dense(128, 32, Flux.relu; initW=Flux.glorot_uniform),
                  Dense(32, num_actions; initW=Flux.glorot_uniform))

    target_network = mapleaves(Flux.Tracker.data, deepcopy(model)::typeof(model))

    return DQNAgent(model,
                    target_network,
                    ADAM(0.001),
                    QLearning(γ),
                    ϵGreedy(ϵ),
                    1000000,
                    γ,
                    batch_size,
                    tn_counter_init,
                    s)
end

function plot_layers(agent::DQNAgent, data_range)


    y = maximum.(Flux.data.(agent.model.(data_range)))

    # println(y)
    
    # for layer in model
    #     vis_data_x = collect.(collect(Iterators.product(-1.0:0.001:1.0, -1.0:0.001:1.0)))
    #     temp_model = model[layer:end]
    #     front_model = identity
    #     if layer != 1
    #         front_model = model[1:layer-1]
    #     end

    #     y = getindex.(findmax.(temp_model.(vis_data_x)), 2)
    #     plt = heatmap(collect(-1.0:0.001:1.0), collect(-1.0:0.001:1.0), y, c=ColorGradient([:red,:blue]), alpha=0.5)
    #     y_front = Flux.data.(front_model.(collect.(zip(class_1.(-1.0:0.001:1.0), -1.0:0.001:1.0))))
    #     y_front_2 = Flux.data.(front_model.(collect.(zip(class_2.(-1.0:0.001:1.0), -1.0:0.001:1.0))))
    #     plot!(plt, getindex.(y_front, 2), getindex.(y_front, 1), c=:red)
    #     plot!(plt, getindex.(y_front_2, 2), getindex.(y_front_2, 1), c=:blue)
    #     layer_plots[layer] = plt
    # end
end


function episode!(env, agent, rng, max_steps)
    terminal = false
    s_t = start!(env, rng)
    action = start!(agent, s_t, rng)

    total_rew = 0
    steps = 0

    while !terminal
        
        s_tp1, rew, terminal = step!(env, action)
        if steps == max_steps
            terminal = true
        end
        action = step!(agent, s_tp1, rew, terminal, rng)
        total_rew += rew
        steps += 1
    end
    return total_rew, steps
end


function main_experiment(seed, num_episodes)

    lg=TBLogger("tensorboard_logs/run", min_level=Logging.Info)
    
    mc = MountainCar(0.0, 0.0, true)
    Random.seed!(Random.GLOBAL_RNG, seed)

    s = JuliaRL.get_state(mc)
    
    agent = construct_agent(s, length(JuliaRL.get_actions(mc)))::DQNAgent

    total_rews = zeros(num_episodes)
    steps = zeros(Int64, num_episodes)

    
    front = ['▁' ,'▂' ,'▃' ,'▄' ,'▅' ,'▆', '▇']
    p = ProgressMeter.Progress(
        num_episodes;
        dt=0.01,
        desc="Episode:",
        barglyphs=ProgressMeter.BarGlyphs('|','█',front,' ','|'),
        barlen=Int64(floor(500/length(front))))

    data_range = collect.(collect(Iterators.product(-1.0:0.01:1.0, -1.0:0.01:1.0)))
    # with_logger(lg) do
    for e in 1:num_episodes
        total_rews[e], steps[e] = episode!(mc, agent, Random.GLOBAL_RNG, 50000)
        next!(p)        
    end

    # end

    return agent.model, total_rews, steps
    
end

end

