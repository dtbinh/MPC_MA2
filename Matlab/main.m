% loads:
%    hovering equilibrium (xs,us)
%    continuous time matrices Ac,Bc of the linearization
%    matrices sys.A, sys.B of the inner-loop discretized with sampling period sys.Ts
%    outer controller optimizer instance
clear;

% run mpt_startup
% tbxmanager restorepath

load('quadData.mat')
outerController = getOuterController(Ac, 'quadprog');
disp('Data successfully loaded')

%% %%%%%%%%%%%%%% First MPC controller %%%%%%%%%%%%%%%%%%%

% vvvvvvvvvvvvvvvv OUR CODE HERE vvvvvvvvvvvvvvvvvvv
% definitions
N = 100;
n_states = size(sys.A, 1);
n_inputs = size(sys.B, 2);
n_ref = 4;

Q = diag([1 100 100 1 1 1 1]);
R = eye(n_inputs);

% Inequalities on x
x_min = [-1;deg2rad([-10;-10;-360;-15;-15;-60])];
x_max = [1;deg2rad([10;10;360;15;15;60])];

% Inequalities on u
u_min = zeros(4,1);
u_max = ones(4,1);

% Terminal cost
[~,Qf] = dlqr(sys.A,sys.B,Q,R);

% Initial state
x0 = [-1; deg2rad(10); deg2rad(-10); deg2rad(120); 0 ; 0 ; 0];

x = sdpvar(n_states,N,'full');
u = sdpvar(n_inputs,N,'full');
xs_inner = xs(6:12); % Inner loop states
us_inner = us;

% u_min <= u_NL <= u_max becomes u_min-us <= u <= u_max-us because of
% linearization around us (U_NL is the nonlinear vector of inputs). 
% Same for constraints on x.
constraint = (x(:,2) == sys.A*x(:,1) + sys.B*u(:,1));
constraint = [constraint, (u_min-us_inner <= u(:,1) <= u_max-us_inner)];
objective = (u(:,1)-us_inner)'*R*(u(:,1)-us_inner);

for i = 2:N-1
    constraint = [constraint, (x(:,i+1) == sys.A*x(:,i) + sys.B*u(:,i))];
    constraint = [constraint, (x_min-xs_inner <= x(:,i) <= x_max-xs_inner)];
    constraint = [constraint, (u_min-us_inner <= u(:,i) <= u_max-us_inner)];

    objective = objective + (x(:,i)-xs_inner)'*Q*(x(:,i)-xs_inner) + ...
        (u(:,i)-us_inner)'*R*(u(:,i)-us_inner);
end

objective = objective + (x(:,N)-xs_inner)'*Qf*(x(:,N)-xs_inner);


%% Solving

options = sdpsettings('solver','quadprog');
options.quadprog.Algorithm = 'interior-point-convex';
innerController = optimizer(constraint, objective, options, x(:,1), u(:,1));

[xt, ut, t] =  simQuad(sys,innerController,x0,N*sys.Ts);

% ^^^^^^^^^^^^^^^^ OUR CODE HERE ^^^^^^^^^^^^^^^^^^^

%pause

%% Reference tracking - no disturbance, no invariant sets
fprintf('PART II - reference tracking...\n')

C = [eye(n_ref) zeros(n_ref,n_states-n_ref)];

r = C*x0+[0.5;-0.1;0.1;-0.1];

% Computer x_r, u_r
sym_time_r = 0.1;
xr = sdpvar(n_states,1,'full');
ur = sdpvar(n_inputs,1,'full');
constraint = ((eye(n_states) - sys.A)*xr - sys.B*ur == zeros(n_states, 1));
constraint = [constraint, (C*xr == r)];
constraint = [constraint, (x_min <= xr <= x_max)];
constraint = [constraint, (u_min <= ur <= u_max)];

objective = ur'*R*ur;

%options = sdpsettings('solver','qpip'); % supposed to be qpip
options = sdpsettings('solver','quadprog');
options.quadprog.Algorithm = 'interior-point-convex';
ref = optimizer(constraint, objective, options, xr, ur);
[xr, ur, t] =  simQuad( sys, ref, x0, sym_time_r);

pause

if get_xr == 0
    xr = sdpvar(n_states,1,'full');
    ur = sdpvar(n_inputs,1,'full');
    
    constraint = ( (eye(n_states) - sys.A)*xr - sys.B*(ur - us) == zeros(n_states, 1) );
    constraint = [constraint, (H*xr <= h)];
    constraint = [constraint, (G*(ur - us) <= g)];
    
    objective = (C*xr - r)'*R*(C*xr - r);
    
    options = sdpsettings('solver','quadprog'); % supposed to be qpip
    innerController = optimizer(constraint, objective, options, xr, ur);
    [xr, ur, t] =  simQuad( sys, innerController, x0, sym_time_r);
end

% system to resolve: as above with -us -ur instead of just -us

pause

%% Nonlinear model simulation - no disturbance
fprintf('Running the FIRST NL model simulation...\n')
sim('simulation1.mdl') 

pause

%% Disturbance estimation
%estimator


%% Offset free MPC
fprintf('PART III - OFFSET FREE / Disturbance rejection...\n')

pause

%% Final simulation
fprintf('Running the FINAL NL model simulation...\n')
sim('simulation2.mdl') 
pause
%% BONUS - Slew rate constraints
% run after doing nonlinear simulations otherwise the NL simulations won't
% work (because of the additional controller argument)
fprintf('BONUS - SLEW RATE CONSTRAINTS...\n')






