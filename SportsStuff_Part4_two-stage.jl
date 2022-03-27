using JuMP
using Gurobi
#using Cbc

M = 9999999999999999999

Zone = ["Northwest", "Southwest", "Upper Midwest", "Lower Midwest", "Northeast", "Southeast"]
I = length(Zone) # number of customers : 6

Facility = ["Seattle", "Denver", "St. Louis", "Atlanta", "Philadelphia"]
J = length(Facility) # number of locations : 5

# i: customers, j : locations, h: demand, f = fixed component , v= capacity based on warehouse size
Year = ["2007", "2008", "2009", "2010", "2011"]
P = length(Year) #number of years

Size = ["Small", "Large"]
S = length(Size) # number of warehouse sizes

# new demand after 80% growth

#calculated based on 80% growth for the next three years

Demand= [
        320000 576000 1036800 1866240 1866240
        200000 360000 648000 1166400 1166400
        160000 288000 518400 933120 933120
        220000 396000 712800 1283040 1283040
        350000 630000 1134000 2041200 2041200
        175000 315000 567000 1020600 1020600
];

sd_prob = [0.65,0.15,0.10,0.10]
SD = length(sd_prob)

scenario_demand = zeros(I,P,SD)
scenario_demand[:,:,1]= [ #normal
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
];

scenario_demand[:,:,2]= [ #demand significantly lower
    1.0 0.8 0.6 0.6 0.6
    1.0 0.8 0.6 0.6 0.6
    1.0 0.8 0.6 0.6 0.6
    1.0 0.8 0.6 0.6 0.6
    1.0 0.8 0.6 0.6 0.6
    1.0 0.8 0.6 0.6 0.6
];

scenario_demand[:,:,3]= [ #demand significantly higher
    1.0 1.2 1.4 1.4 1.4
    1.0 1.2 1.4 1.4 1.4
    1.0 1.2 1.4 1.4 1.4
    1.0 1.2 1.4 1.4 1.4
    1.0 1.2 1.4 1.4 1.4
    1.0 1.2 1.4 1.4 1.4
];

scenario_demand[:,:,4]= [ #demand spikes in SouthWest
    1.0 1.0 1.0 1.0 1.0
    1.0 1.2 1.4 1.6 1.8
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
    1.0 1.0 1.0 1.0 1.0
];


growth = 1.8

    # Fixed cost based on size of warehouse


Fixed = [
    300000 500000
    250000 420000
    220000 375000
    220000 375000
    240000 400000
];

# Variable cost

Var = [
    0.2 0.2
    0.2 0.2
    0.2 0.2
    0.2 0.2
    0.2 0.2
];
Capacity = [2000000 4000000]

sc_prob = [0.75, 0.15, 0.05, 0.05]
SC = length(sc_prob)

scenario_capacity = zeros(P,S,SC)
scenario_capacity[:,:,1] = [ #normal
    1.0 1.0
    1.0 1.0
    1.0 1.0
    1.0 1.0
    1.0 1.0
]

scenario_capacity[:,:,2] = [ #capacity lower
    1.0 1.0
    0.7 0.7
    0.7 0.7
    0.7 0.7
    0.7 0.7
]

scenario_capacity[:,:,3] = [ #capacity lower for small warehouses
    1.0 1.0
    0.7 1.0
    0.7 1.0
    0.7 1.0
    0.7 1.0
]

scenario_capacity[:,:,4] = [ #capacity lower for large warehouses
    1.0 1.0
    1.0 0.7
    1.0 0.7
    1.0 0.7
    1.0 0.7
]

InvFixed = 475000 ;

InvVar = 0.165 ;

ShippingCost = [
    2.0 2.5 3.5 4.0 4.5
    2.5 2.5 3.5 4.0 5.0
    3.5 2.5 2.5 3.0 3.0
    4.0 3.0 2.5 2.5 3.5
    5.0 4.0 3.0 3.0 2.5
    5.5 4.5 3.5 2.5 4.0
];

model = Model(Gurobi.Optimizer);

    # binary: decision to open a facility of size s in location j in year p
@variable(model, x[j=1:J,s=1:S,p=1:P,sc=1:SC] >= 0, Bin);
    # x[j,s,p]

    # Fraction of demand from zone i to allocate to facility in location j in year p with stochastic elements sd
@variable(model,y[i=1:I,j=1:J,s=1:S,p=1:P,sd=1:SD] >=0);
    # y[i,j,s,p,sd]

    #-------

    #
@objective(model, Min,
sum(x[j,s,p,sc] * (Fixed[j,s] + InvFixed) * sc_prob[sc] for j in 1:J,s in 1:S,p in 1:P,sc in 1:SC) +
sum(y[i,j,s,p,sd] * (Demand[i,p]*scenario_demand[i,p,sd]) * (Var[j,s] + InvVar + ShippingCost[i,j]) * sd_prob[sd] for i in 1:I,j in 1:J,s in 1:S,p in 1:P,sd in 1:SD));

    #-------

    # equation (2)
    # Cannot open a small and large facility in the same location for each capacity-scenario
@constraint(model, [j=1:J,p=1:P,sc=1:SC], sum(x[j,s,p,sc] for s in 1:S) <= 1);

    # equation (5)
    # can only assign demand to open facilities
@constraint(model, [i=1:I,j=1:J,s=1:S,p=1:P,sd=1:SD,sc=1:SC], y[i,j,s,p,sd] <= x[j,s,p,sc]*M);

    # equation (6)
    # no unassigned demand for any year
@constraint(model, [i=1:I,p=1:P,sd=1:SD], sum(y[i,j,s,p,sd] for j in 1:J, s in 1:S) == 1);

    # equation (7)
    # Capacity constraint (Cannot allocate more demand to a facility j than there is capacity for)
@constraint(model, [j=1:J,p=1:P,sd=1:SD,sc=1:SC], sum(y[i,j,s,p,sd]*(Demand[i,p]*scenario_demand[i,p,sd]) for i in 1:I, s in 1:S) <= sum(x[j,s,p,sc]*(Capacity[s]*scenario_capacity[p,s,sc]) for s in 1:S));

#non-anticipatory constraint
@constraint(model, [sc=1:SC-1,j=1:J,s=1:S], x[j,s,1,sc] == x[j,s,1,sc+1])

    #-------
    # SOLVE
    #-------

optimize!(model)

println();

Total_demand = zeros(J,P,SD)

if termination_status(model) == MOI.OPTIMAL
    println("Optimal objective value = $(objective_value(model))")
    println("   ")
    println("----------------------")
    println("   ")
    for sd=1:SD
        println("Demand scenario = ",sd)
        for sc=1:SC
            println("Capacity scenario = ",sc )
            for p = 1:P
                println("Production year = $(Year[p]) ")
                println("   ")
                for j = 1:J
                    for s = 1:S
                        if value(x[j,s,p,sc]) == 1
                            println("Facility = $(Facility[j]) | Size = $(Size[s])")
                            println(" Serving demand zone: ")
                            for i = 1:I
                                if value(y[i,j,s,p,sd]) != 0
                                    println("  $(Zone[i]) = $( value(y[i,j,s,p,sd])*Demand[i,p]*scenario_demand[i,p,sd]) " )
                                    Total_demand[j,p,sd] += value(y[i,j,s,p])*Demand[i,p]*scenario_demand[i,p,sd]
                                end
                            end
                            println(" Total demand served = $(Total_demand[j,p,sd])" )
                            println("   ")
                        end
                    end
                end
                println("----------------------")
                println("   ")
            end
        end
    end
else
    println("No optimal solution available")
end
