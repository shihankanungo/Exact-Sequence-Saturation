from itertools import permutations,combinations, product
import numpy as np
from numpy.typing import NDArray


Pattern = NDArray[np.int_]
MatrixIndex = tuple[int, int]
PatternCopy = tuple[MatrixIndex, ...]


def make_pattern(r: int, u: list) -> Pattern:
    '''Turns a sequence u into a 0-1 matrix'''
    P = np.zeros((r,len(u)))
    for i in range(len(u)):
        for j in range(r):
            if u[i] == j:
                P[j][i] = 1
    return P


def make_patterns(r: int, u: list) -> list:
    '''All possible patterns corresponding to u'''
    patterns = []
    for rows in permutations(range(r)):
        Q = np.zeros((r,len(u)))
        for i in range(len(u)):
            Q[rows[u[i]]][i] = 1
        patterns.append(Q)
    return patterns

def make_patterns_plus(r: int, u: list) -> list:
    '''Patterns corresponding to u with two ones in a column (first type)'''
    patterns_plus = []
    for rows in permutations(range(r)):
        for i in range(len(u)-1):
            Q = np.zeros((r,len(u)-1))
            if rows[u[i]] > rows[u[i+1]]:
                for j in range(i+1):
                    Q[rows[u[j]]][j] = 1
                for k in range(i+1,len(u)):
                    Q[rows[u[k]]][k-1] = 1
                patterns_plus.append(Q)
    return patterns_plus

def make_patterns_minus(r: int, u: list) -> list:
    '''Patterns corresponding to u with two ones in a column (second type)'''
    patterns_minus = []
    for rows in permutations(range(r)):
        for i in range(len(u)-1):
            Q = np.zeros((r,len(u)-1))
            if rows[u[i]] < rows[u[i+1]]:
                for j in range(i+1):
                    Q[rows[u[j]]][j] = 1
                for k in range(i+1,len(u)):
                    Q[rows[u[k]]][k-1] = 1
                patterns_minus.append(Q)
    return patterns_minus


u = [0,1,2,1,0]
r = 3
n = 3
l = len(u)
N = 6

# define A(i,j), P, P^+, P^-, A^+(i,j), A^-(i,j)
P = make_pattern(r,u)
patterns_plus = make_patterns_plus(r,u)
print(patterns_plus)

patterns_minus = make_patterns_minus(r,u)
print(patterns_minus)
A = dict[MatrixIndex, list[PatternCopy]]()
A_plus = dict[MatrixIndex, list[PatternCopy]]()
A_minus = dict[MatrixIndex, list[PatternCopy]]()
print(P)

P_copies = list[PatternCopy]()
for mat_idx in product(range(n), range(N)):
    A[mat_idx] = []
for rows, cols in product(permutations(range(n), int(r)),
                          combinations(range(N), l)):

    P_copy = tuple(
        (rows[x], cols[y]) \
        for x, y in product(range(len(rows)), range(len(cols))) \
        if P[x][y]
    )
    P_copies.append(P_copy)
    for mat_idx in P_copy:
        A[mat_idx].append(P_copy)
P_copies_plus = list[PatternCopy]()
for mat_idx in product(range(n), range(N)):
    A_plus[mat_idx] = []
for rows, cols in product(permutations(range(n), int(r)),
                          combinations(range(N), l-1)):
    for P_plus in patterns_plus:
        P_copy_plus = tuple(
            (rows[x], cols[y]) \
            for x, y in product(range(len(rows)), range(len(cols))) \
            if P_plus[x][y]
        )
        P_copies_plus.append(P_copy_plus)
        for mat_idx in P_copy_plus:
            A_plus[mat_idx].append(P_copy_plus)
P_copies_minus = list[PatternCopy]()
for mat_idx in product(range(n), range(N)):
    A_minus[mat_idx] = []
for rows, cols in product(permutations(range(n), int(r)),
                          combinations(range(N), l-1)):
    for P_minus in patterns_minus:
        P_copy_minus = tuple(
            (rows[x], cols[y]) \
            for x, y in product(range(len(rows)), range(len(cols))) \
            if P_minus[x][y]
        )
        P_copies_minus.append(P_copy_minus)
        for mat_idx in P_copy_minus:
            A_minus[mat_idx].append(P_copy_minus)

# Set up the program and constraints
program = MixedIntegerLinearProgram(solver = 'GLPK')
x = program.new_variable(binary=True)
y = program.new_variable(binary=True)
for j in [0]:
    program.add_constraint(program.sum(x[mat_idx] for mat_idx in product(range(n),[j]))==1)
for mat_idx in product(range(n), range(N)):
    program.add_constraint(
        x[mat_idx] <= 1
    )
    program.add_constraint(
        x[mat_idx] >= 0
    )

for P_copy in P_copies:
    program.add_constraint(
        program.sum(x[mat_idx] for mat_idx in P_copy) <= l - 1
    ) # Doesn't contain P
    program.add_constraint(
        (l - 1) * y[P_copy] - sum(x[mat_idx] for mat_idx in P_copy) <= 0
    )
    program.add_constraint(
        y[P_copy] - sum(x[mat_idx] for mat_idx in P_copy) >= 2 - l
    ) # Conditions on x and y
for P_copy_plus in P_copies_plus:
    program.add_constraint(
        (l - 1) * y[P_copy_plus] - sum(x[mat_idx] for mat_idx in P_copy_plus) <= 0
    )
    program.add_constraint(
        y[P_copy_plus] - sum(x[mat_idx] for mat_idx in P_copy_plus) >= 2 - l
    ) # Conditions on y
for P_copy_minus in P_copies_minus:
    program.add_constraint(
        (l - 1) * y[P_copy_minus] - sum(x[mat_idx] for mat_idx in P_copy_minus) <= 0
    )
    program.add_constraint(
        y[P_copy_minus] - sum(x[mat_idx] for mat_idx in P_copy_minus) >= 2 - l
    ) # Conditions on y

for j in range(N):
    program.add_constraint(
        program.sum(x[mat_idx] for mat_idx in product(range(n),[j])) <= 1
    ) # at most one 1 in each column
for j in range(N-1):
    program.add_constraint(
        program.sum(x[mat_idx] for mat_idx in product(range(n),[j])) >= program.sum(x[mat_idx] for mat_idx in product(range(n),[j+1]))
    ) # left justified

for j in range(N-r+1):
    for i in range(n):
        program.add_constraint(
            program.sum(x[mat_idx] for mat_idx in product([i],range(j,j+r))) <= 1
        ) # r-sparsity
for mat_idx in product(range(n),range(N)):
    '''Saturation Conditions'''
    i = mat_idx[0]
    j = mat_idx[1]
    program.add_constraint(
        program.sum(y[P_copy] for P_copy in A[mat_idx]) + program.sum(y[P_copy_plus] for P_copy_plus in A_plus[mat_idx])  - program.sum(x[mat_idx0] for mat_idx0 in product(range(i+1,n),[j])) + program.sum(x[mat_idx0] for mat_idx0 in product([i],range(max(j-r+1,0),min(j+r-1,N)))) >= 0
    )
    program.add_constraint(
        program.sum(y[P_copy] for P_copy in A[mat_idx]) + program.sum(y[P_copy_plus] for P_copy_plus in A_plus[mat_idx])  - program.sum(x[mat_idx0] for mat_idx0 in product(range(i),[j])) + program.sum(x[mat_idx0] for mat_idx0 in product([i],range(max(j-r+2,0),min(j+r,N)))) >= 0
    )
    program.add_constraint(
        program.sum(y[P_copy] for P_copy in A[mat_idx]) + program.sum(y[P_copy_minus] for P_copy_minus in A_minus[mat_idx])  - program.sum(x[mat_idx0] for mat_idx0 in product(range(i+1,n),[j])) + program.sum(x[mat_idx0] for mat_idx0 in product([i],range(max(j-r+2,0),min(j+r,N)))) >= 0
    )
    program.add_constraint(
        program.sum(y[P_copy] for P_copy in A[mat_idx]) + program.sum(y[P_copy_minus] for P_copy_minus in A_minus[mat_idx])  - program.sum(x[mat_idx0] for mat_idx0 in product(range(i),[j])) + program.sum(x[mat_idx0] for mat_idx0 in product([i],range(max(j-r+1,0),min(j+r-1,N)))) >= 0
    )
for i in range(r):
    program.add_constraint(
        x[(i,i)] == 1
    )
program.set_objective(
    -sum(x[mat_idx] for mat_idx in product(range(n), range(N)))
)
print(-1 * program.solve())
A = np.zeros((n,N))
for mat_idx, v in sorted(program.get_values(x).items()):
    A[mat_idx] = v
print(A)
