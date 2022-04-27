using JuMP
# using Cbc
using Cbc

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


Total_demand = [
    0.0 0.0 0.0 0.0 0.0
    0.0 0.0 0.0 0.0 0.0
    0.0 0.0 0.0 0.0 0.0
    0.0 0.0 0.0 0.0 0.0
    0.0 0.0 0.0 0.0 0.0
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
Capacity = [2000000 4000000] # s as looping variable with value from 1:S
# S = length(Capacity) = 2

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

MinLease = 3 ;

model = Model(Cbc.Optimizer);

    # binary: decision to open a facility of size s in location j in year p
@variable(model, x[j=1:J,s=1:S,p=1:P] >= 0, Bin);
    # x[j,s,p]

    # Fraction of demand from zone i to allocate to facility in location j in year p
@variable(model,y[i=1:I,j=1:J,s=1:S,p=1:P] >=0);

    # y[i,j,s,p]

    # Tracking the year when the facility was first opened
@variable(model, z[j=1:J,s=1:S,p=1:P] >=0, Bin);
    # z[j,p]
    #-------

    #
@objective(model, Min,
sum(x[j,s,p] * (Fixed[j,s] + InvFixed) for j in 1:J, s in 1:S, p in 1:P) +
sum(y[i,j,s,p] * Demand[i,p] * (Var[j,s] + InvVar + ShippingCost[i,j]) for i in 1:I, j in 1:J, s in 1:S, p in 1:P));

    #-------

    # equation (2)
    # Cannot open a small and large facility in the same location
@constraint(model, [j = 1:J, p = 1:P], sum(x[j,s,p] for s in 1:S) <= 1);

    # equation (3)
    # Must update the tracking variable z if a facility f was not open in the previous year
@constraint(model, [j=1:J,s=1:S,p=1:P], z[j,s,p] >= x[j,s,p] - (p>1 ? x[j,s,p-1] : 0));

    # equation (4)
    # If a facility is leased, the lease must be of minimum 3 years length
@constraint(model, [j=1:J,s=1:S], sum(z[j,s,p]*min(MinLease,P-p+1) for p in 1:P) <= sum(x[j,s,p] for p in 1:P));

    # equation (5)
    # can only assign demand to open facilities
@constraint(model, [i=1:I,j=1:J,s=1:S,p=1:P], y[i,j,s,p] <= x[j,s,p]);

    # equation (6)
    # no unassigned demand for any year
@constraint(model, [i=1:I,p=1:P], sum(y[i,j,s,p] for j in 1:J, s in 1:S) == 1);

    # equation (7)
    # Capacity constraint (Cannot allocate more demand to a facility j than there is capacity for)
@constraint(model, [j=1:J,p=1:P], sum(y[i,j,s,p]*Demand[i,p] for i in 1:I, s in 1:S) <= sum(x[j,s,p]*Capacity[s] for s in 1:S));

    #-------
    # SOLVE
    #-------

optimize!(model)

println();

if termination_status(model) == MOI.OPTIMAL
    println("Optimal objective value = $(objective_value(model))")
    println("   ")
    println("----------------------")
    println("   ")
    for p = 1:P
        println("Production year = $(Year[p]) ")
        println("   ")
        for j = 1:J
            for s = 1:S
                if value(x[j,s,p]) == 1
                    println("Facility = $(Facility[j]) | Size = $(Size[s])")
                    println(" Serving demand zone: ")
                    for i = 1:I
                        if value(y[i,j,s,p]) != 0
                            println("  $(Zone[i]) = $( value(y[i,j,s,p])*Demand[i,p]) " )
                            Total_demand[j,p] += value(y[i,j,s,p])*Demand[i,p]
                        end
                    end
                    println(" Total demand served = $(Total_demand[j,p])" )
                    println("   ")
                end
            end
        end
        println("----------------------")
        println("   ")
    end
else
    println("No optimal solution available")
end
