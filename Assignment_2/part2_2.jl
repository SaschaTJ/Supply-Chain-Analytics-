using JuMP
using Gurobi
import Random


#------
# DATA
#------

### SETS
vehicles = [1 2 3];
K = length(vehicles);
DCs = [ 1 2 3 4 5 6];
I = length(DCs);
days = [1 2 3 4 5 6 7 8]
T = length(days); #number of time periods

Capdc = [999999 502 488 220 486 742]; #inventory holding capacity at every node including depot
Captruck = 900; #capacity of each truck
h = 0.025; # inventory holding cost at customers
Inv_begin = [0 98.8 153.9 42.4 23.4 85.7]; # inventory at the nodes at the beginning of the period

shippingCost = [0 140 434 389 419 125
    140 0 300 455 400 97
    434 300 0 609 417 330
    389 455 609 0 256 358
    419 400 417 256 0 316
    125 97 330 358 316 0
]; # transporation cost including from depot (matrix flipped from original data)

demand = [0 0 0 0 0 0 0 0 
    75.9 75.9 75.9 75.9 75.9 85.7 85.7 75.9
    62.9 94.8 94.8 94.8 94.8 68.65 36.75 62.9
    67.2 67.2 67.2 67.2 67.2 67.15 67.15 67.2
    102.3 156.0 156.0 156.0 156.0 119.05 65.35 102.3
    107.4 130.1 130.1 130.1 130.1 65.15 42.45 107.4
]; #demand at all customers (rows) for every time period(columns)





demand_std = [
    118.7434209	118.7434209	118.7434209	118.7434209	118.7434209	146.8843082	146.8843082	118.7434209
    109.0871211	138.9244399	138.9244399	138.9244399	138.9244399	141.4213562	112.2497216	109.0871211
    112.6942767	112.6942767	112.6942767	112.6942767	112.6942767	128.6468033	128.6468033	112.6942767
    131.9090596	160.3121954	160.3121954	160.3121954	160.3121954	150.4991694	119.7914855	131.9090596
    130.3840481	140	140	140	140	110.792599	98.36157786	130.3840481
];

#demand_std = [
#    43 43 43 43 43 46.5 46.5 43
#    39 59 59 59 59 44 24 39
#    41 41 41 41 41 42 42 41
#    56 85 85 85 85 65 36 56
#    60 72 72 72 72 34.5 22.5 60
#]

model = Model(Gurobi.Optimizer);

@variable(model, x[i=1:I,j=1:I,k=1:K,t=1:T], Bin); #vehicle k goes from i to j in period t
@variable(model, y[i=1:I,k=1:K,t=1:T], Bin); #vehicle k visits node i in period t
@variable(model, z[i=2:I,k=1:K,t=1:T] >= 0); #load carried by vehicle k when arriving at node i in period t
@variable(model, p[i=1:I,t=1:T] >=0); # inventory at node i in time period t
#@variable(model, r[t=1:T] >=0); #supply available at depot (node 0) at time t
@variable(model, q[i=2:I,k=1:K,t=1:T] >=0); # Quantity delivered to customer i by vehicle k at start of period t

@objective(model, Min,sum(h*p[i,t] for i in 2:I, t in 1:T)+ sum(shippingCost[i,j]*x[i,j,k,t] for i in 1:I,j in 1:I,k in 1:K,t in 1:T));

#_______________ pure VRP

# Constraint 4: A customer got visit by not more than one truck in one period:
@constraint(model, [i=2:I,t=1:T], sum(y[i,k,t] for k in 1:K) <= 1);

# Constraint 5: Vehicle capacity
@constraint(model, [k=1:K,t=1:T], sum(demand[i,t]*y[i,k,t] for i in 1:I) <= Captruck);

# Constraint 5_1 : Inflow: if vehicle k visits node i, inflow of vehicle k should be 1, 0, otherwise
#                  Outflow: if vehicle k visits node i, outflow of vehicle k should be 1, 0, otherwise
#part 1
@constraint(model, [i=1:I,k=1:K,t=1:T], sum(x[i,j,k,t] for j in 1:I) == sum(x[j,i,k,t] for j in 1:I));
#part 2
@constraint(model, [i=1:I,k=1:K,t=1:T], sum(x[i,j,k,t] for j in 1:I) == y[i,k,t]);

# Constraint 6: Subtour elimination constraint : load should reduce while going from i to j
# @constraint(model, [i=2:I,j=2:J,k=1:K,t=1:T], z[i,k,t] - z[j,k,t]>= demand[i,t] -((1-x[i,j,k,t])*sum(demand[i,t] for i in 1:I)))
@constraint(model, [i=2:I,j=2:I,k=1:K,t=1:T], z[i,k,t] - z[j,k,t] >= demand[i,t] - ((1-x[i,j,k,t]) * sum(demand[a,t] for a in 1:I) ));
#not sure if D is sum demand from 1:I or 2:I

#_______________ Inventory optimization

# Constraint 0: Initializing the first set of inventories
#@constraint(model, [i= 1:I], I_time[i,1] == I_begin[i]); # I[i,0] from slide

# Constraint 1: Flow balance constraints at depot in each period t:


@constraint(model, [t=1:T-1], p[1,t] == p[1,t+1] + sum(q[i,k,t+1] for i in 2:I, k in 1:K));

# Constraint 2: Flow balance constraints at each customer i in each period t:

@constraint(model, [i=2:I,t=1:T], (t == 1 ? Inv_begin[i] : p[i,t-1]) + sum(q[i,k,t] for k in 1:K) == p[i,t] + demand[i,t])

# Constraint 3: Inventory capacity constraints at each customer i in each period t:

@constraint(model, [i=2:I,t=1:T], (t == 1 ? Inv_begin[i] : p[i,t-1]) + sum(q[i,k,t] for k in 1:K) <= Capdc[i]);

#_______________ Linking both parts

# Constraint 7: Linking the inventory part of the model to the VRP part:
    # Constraint 7a: Amount delivered to a customer cannot exceed the holding capacity of the customer

@constraint(model, [i=2:I,k=1:K,t=1:T], q[i,k,t] <= Capdc[i]*y[i,k,t]);

    # Constraint 7b: Inventory delivered to a customer cannot exceed the truck capacity

@constraint(model, [k=1:K,t=1:T], sum(q[i,k,t] for i in 2:I) <= Captruck*y[1,k,t]);

#-------
# SOLVE
#-------

optimize!(model);

println();

if termination_status(model) == MOI.OPTIMAL
    println("Optimal objective value = $(objective_value(model))")
    println("   ")
    println("----------------------")
    println("   ")

end

demand = [
    75.9 75.9 75.9 75.9 75.9 85.7 85.7 75.9
    62.9 94.8 94.8 94.8 94.8 68.65 36.75 62.9
    67.2 67.2 67.2 67.2 67.2 67.15 67.15 67.2
    102.3 156.0 156.0 156.0 156.0 119.05 65.35 102.3
    107.4 130.1 130.1 130.1 130.1 65.15 42.45 107.4
];

actual_inventory = zeros(I-1,T)
fill_rates_count = zeros(I-1,T)
Random.seed!(0);
for r = 1:10000
    #println("Iteration: ",r)
    actual_demand = demand + (randn(I-1,T).*demand_std)
    for t=1:T
        for i=1:I-1
            delivered = 0
            for k=1:K
                delivered += value(q[i+1,k,t])
            end
            actual_demand[i,t] = max(actual_demand[i,t],0)
            actual_inventory[i,t] = (t>1 ? actual_inventory[i,t-1] : Inv_begin[i+1]) + delivered - actual_demand[i,t]
            if actual_inventory[i,t] < 0
                fill_rate = (-actual_inventory[i,t])/actual_demand[i,t]
                actual_inventory[i,t] = 0
            else
                fill_rate = 1
            end
            if fill_rate>=0.95
                fill_rates_count[i,t] += 1
            end
            #println("DC: ",i)
            #println("Demand: ",actual_demand[i,t])
            #println(" | Inventory: ",actual_inventory[i,t])
            #println(fill_rate)
        end
    end 
end
