
using Flux
using Random

mutable struct ImageDQNAgent_old{M, TN, O, LU, AP<:AbstractValuePolicy, Φ, ER<:AbstractImageReplay} <: AbstractAgent
    model::M
    target_network::TN
    opt::O
    lu::LU
    ap::AP
    er::ER
    batch_size::Int
    tn_counter_init::Int
    target_network_counter::Int
    wait_time::Int
    wait_time_counter::Int
    exp_wait_size::Int
    action::Int
    prev_s::Φ
end

ImageDQNAgent_old(model,
              target_network,
              image_replay,
              opt,
              lu,
              ap,
              size_buffer,
              batch_size,
              tn_counter_init,
              wait_time,
              exp_wait_size) =
    ImageDQNAgent_old(model,
                  target_network,
                  opt,
                  lu,
                  ap,
                  image_replay,
                  batch_size,
                  tn_counter_init,
                  tn_counter_init,
                  wait_time,
                  0,
                  exp_wait_size,
                  0,
                  zeros(Int, image_replay.hist))


function get_action(agent::ImageDQNAgent_old, s)

end

function _start!(agent::ImageDQNAgent_old,
                       env_s_tp1,
                       rng::AbstractRNG;)

    # Start an Episode
    agent.prev_s .= add!(agent.er, env_s_tp1)

    prev_s =
        cat(getindex(agent.er.image_buffer, agent.prev_s)./256f0;
            dims=4) |> gpu
    
    agent.action = sample(agent.ap,
                          cpu(agent.model(prev_s)),
                          rng)

    return agent.action
end

function _step!(agent::ImageDQNAgent_old,
                      env_s_tp1,
                      r,
                      terminal,
                      rng::AbstractRNG;)

    cur_s = add!(agent.er,
                 (agent.prev_s,
                  findfirst((a)->a==agent.action,
                            agent.ap.action_set),
                  env_s_tp1,
                  r,
                  terminal))
    
    update_params!(agent, rng)

    agent.prev_s .= cur_s

    prev_s = 
        cat(getindex(agent.er.image_buffer, agent.prev_s)./256f0;
            dims=4) |> gpu

    agent.action = sample(agent.ap,
                          cpu(agent.model(prev_s)),
                          rng)

    return agent.action
end

function update_params!(agent::ImageDQNAgent_old, rng)
    

    if size(agent.er)[1] > agent.exp_wait_size
        agent.wait_time_counter -= 1
        if agent.wait_time_counter <= 0

            e = sample(agent.er,
                       agent.batch_size;
                       rng=rng)
            s = gpu(e.s)
            r = gpu(e.r)
            t = gpu(e.t)
            sp = gpu(e.sp)
            
            update!(agent.model,
                    agent.lu,
                    agent.opt,
                    s,
                    e.a,
                    sp,
                    r,
                    t,
                    agent.target_network)

            agent.wait_time_counter = agent.wait_time
        end
    end
    
    # Target network updates 
    if !(agent.target_network isa Nothing)
        if agent.target_network_counter == 1
            agent.target_network_counter = agent.tn_counter_init
            for ps ∈ zip(params(agent.model),
                         params(agent.target_network))
                ps[2] .= ps[1]
            end
        else
            agent.target_network_counter -= 1
        end
    end

    return nothing    
end
