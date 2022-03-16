using JuMP
# using Cbc
using Gurobi

Demand = ["Northwest", "Southwest", "Upper Midwest", "Lower Midwest", "Northeast", "Southeast"]
I = length(Demand) # number of customers : 6

Facilities = ["Seattle", "Denver", "St. Louis", "Atlanta", "Philadelphia"]
J = length(Facilities) # number of locations : 5

# i: customers, j : locations, h: demand, f = fixed component , v= capacity based on warehouse size
Years = ["2007", "2008", "2009", "2010", "2011"]
P = length(Years) #number of years

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

model = Model(Gurobi.Optimizer);

    # binary: decision to open a facility of size s in location j in year p
@variable(model, x[j = 1:J, s = 1:S, p = 1:P] >= 0, Bin);
    # x[j,s,p]

    # Fraction of demand from zone i to allocate to facility in location j in year p
@variable(model,y[i = 1:I, j = 1:J, s = 1:S,p = 1:P] >=0);

    # y[i,j,p]

    # Tracking the year when the facility was first opened
@variable(model, z[j = 1:J, p = 1:P] >=0, Bin);
    # z[j,p]

    #-------

    #
@objective(model, Min,
sum(x[j,s,p] * (Fixed[j,s]+InvFixed) for j in 1:J,p in 1:P,s in 1:S) +
sum(y[i,j,s,p] * Demand[i,p] * (Var[j,s] + InvVar + ShippingCost[i,j]) for i in 1:I, j in 1:J, s in 1:S,p in 1:P));

    #-------

    # edited
    # equation (2)
    # Cannot open a small and large facility in the same location
@constraint(model, [j = 1:J, p = 1:P], sum(x[j,s,p] for s in 1:S) <= 1);

    # edited
    # equation (3)
    # Must update the tracking variable z if a facility f was not open in the previous year
@constraint(model, [j = 1:J, p = 2:P], z[j,p] <= sum(x[j,s,p] for s in 1:S) - sum(x[j,s,p-1] for s in 1:S));

    # new
    # equation (4)
    # If a facility is leased, the lease must be of minimum 3 years length
@constraint(model, [j = 1:J], sum(z[j,p]*min(MinLease,P-p) for p in 1:P) <= sum(x[j,s,p] for s in 1:S, p in 1:P));

    # edited
    # equation (5) - need to correct constrint equation in Overleaf
    # can only assign demand to open facilities
@constraint(model, [i = 1:I, j = 1:J, s=1:S,p = 1:P], y[i,j,s,p] <= x[j,s,p]);

    # edited
    # equation (6) - need to correct constrint equation in Overleaf
    # no unassigned demand for any year
@constraint(model, [i in 1:I, p = 1:P], sum(y[i,j,s,p] for j in 1:J,s in 1:S) == 1);

    # edited
    # equation (7)
    # Capacity constraint (Cannot allocate more demand to a facility j than there is capacity for)
@constraint(model, [j = 1:J, p = 1:P], sum(y[i,j,s,p]*Demand[i,p] for i in 1:I,s in 1:S) <= sum(x[j,s,p]*Capacity[s] for s in 1:S));

    # edited
    # equation (8)
    # non-negativity constraint, cannot allocate negative demand

@constraint(model, [i = 1:I, j = 1:J, s = 1:S, p = 1:P], y[i,j,s,p] >= 0);

    # @constraint(model,yr > 1 ? [j=1:m,yr = 1:P],  (z[j,yr] <= sum(x[j,c,yr] for c in 1:s)-sum(x[j,c,yr-1] for c in 1:s)) : );
    #  @constraint(model, [i=1:m,j=1:n,yr=1:P], yr <= 4 ? sum(x[j,c,yrj+1] = sum x[j] for j in 3:n | 0)
    #  @constraint(model,[j=1:n,z=1:3],(sum(x[j,c,yr] for yr in z:z+2)== 0 || sum(x[j,c,yr] for yr in z:z+2)== 3))
    #  @constraint(model,[j=1:n,c=1:s,z=1:3],(sum(x[j,c,yr] for yr in z:z+2)== 3))

    #-------
    # SOLVE
    #-------

optimize!(model)

println();

for j = 1:J
    for p = 1:P
        for s = 1:S
            if (value(x[j,s,p]) == 1)
                if (value(z[j,p]) == 1)
                    println("facility: ", Facilities[j]," size: ", Size[s], " year: ", Years[p]);
                end
            end
        end
    end

end
