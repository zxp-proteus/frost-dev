 classdef ContinuousDynamics < DynamicalSystem
    % Continuous state dynamic system governed by differential equations.
    %
    % It could be either a
    % first order system with the form:
    % \f{eqnarray*}{
    % Mmat(x)\dot{x}= Fvec(x) + Gvec(x,u)
    % \f}
    % or a second order system with the form:
    % \f{eqnarray*}{
    % Mmat(x)\ddot{x}= Fvec(x,\dot{x}) + Gvec(x,u)
    % \f}
    % 
    % Further, if the inputs (u) are affine, the system can be written as
    % either for first order system of the form:
    % \f{eqnarray*}{
    % Mmat(x)\dot{x}= Fvec(x) + Gmap(x) u
    % \f}
    % or a second order system of the form:
    % \f{eqnarray*}{
    % Mmat(x)\ddot{x}= Fvec(x,\dot{x}) + Gmap(x) u
    % \f}
    %    
    %
    % @author ayonga @date 2017-02-26
    % 
    % Copyright (c) 2016, AMBER Lab
    % All right reserved.
    %
    % Redistribution and use in source and binary forms, with or without
    % modification, are permitted only in compliance with the BSD 3-Clause 
    % license, see
    % http://www.opensource.org/licenses/bsd-license.php
    
    
    
    % callback function handle properties to implement object specific
    % funtionalities outside of the class without making a new subclass
    properties (SetAccess=protected)
        
        % pre-process function handle of the object before the simulation 
        %
        % @note The function handle should have the syntax:
        % preProcess(sys, controller, params, varargin)
        %
        % @type function_handle
        PreProcess
        
        % pre-process function handle of the object after the simulation 
        %
        % @note The function handle should have the syntax:
        % postPorcess(sys, sol, controller, params, varargin)
        %
        % @type function_handle
        PostPorcess
        
        % A handle to a function called by a trajectory optimization NLP to
        % enforce system specific constraints. 
        %
        % @note The function handle should have the syntax:
        % userNlpConstraint(nlp, bounds, varargin)
        %
        % @type function_handle
        UserNlpConstraint
    end
    
    
    
    
    
    %%
    methods
        function obj = ContinuousDynamics(type, name)
            % The class construction function
            %
            % Parameters:            
            % type: the type of the system @type char
            % name: the name of the system @type char
            
            if nargin > 1
                superargs = {type, name};
            else
                superargs = {type};
            end
            
            obj = obj@DynamicalSystem(superargs{:});
            
            
            
            obj.Fvec = cell(0);
            obj.Mmat = [];
            obj.MmatDx = [];
            
            % do-nothing function handle by default
            obj.PreProcess = str2func('nop');
            obj.PostPorcess = str2func('nop');
            obj.UserNlpConstraint = str2func('nop');
            
        end
        
        
        function obj = addState(obj, x, dx, ddx)
            % overload the superclass 'addState' method with fixed state
            % fields
            % 
            % Parameters:
            % x: the state variables @type SymVariable
            % dx: the first order derivative of state variables @type SymVariable
            % ddx: the second order derivative of state variables @type SymVariable
            
            if strcmp(obj.Type,'FirstOrder')
                obj = addState@DynamicalSystem(obj,'x',x,'dx',dx);
            elseif strcmp(obj.Type, 'SecondOrder')
                obj = addState@DynamicalSystem(obj,'x',x,'dx',dx,'ddx',ddx);
            else
                error('Please define the type of the system first.');
            end
        
        end
        
        
    end
    
    %%
    properties (SetAccess=protected)
        
        
        % The flow (trajectory) from the dynamical system simulation
        %
        % @type struct
        Flow
        
        
        
        % A structure that contains the symbolic representation of state
        % variables
        %
        % Required fields of States:
        %  x: the state variables x(t) @type SymVariable
        %  dx: the first order derivatives of X, i.e. xdot(t)
        %  @type SymVariable
        %
        % Optional fields of States:
        %  ddx: the second order derivatives of X , i.e. xddot(t) 
        %  @type SymVariable
        %
        % @type struct
        % States
        
        
        
        % The mass matrix Mmat(x) 
        %
        % @type SymFunction
        Mmat
        
        
        
        % The cell array of the drift vector fields Fvec(x) SymFunction
        %
        % We split the Fvec into many sub-vectors Fvec[i], such that 
        % \f{eqnarray*}{
        % Fvec = \sum_i^N Fvec[i]
        % \f}
        % @type cell
        Fvec
        
        
        % The holonomic constraints of the dynamical system
        %
        % @type struct
        HolonomicConstraints
        
        
        % The unilateral constraints of the dynamical system
        %
        % @type struct
        UnilateralConstraints
        
        % The virtual constraints of the dynamical system
        %
        % @type struct
        VirtualConstraints
        
        % The event functions
        %
        % The event functions are often subset of the unilateral
        % constraints defined on the system. For flexibility, we define
        % them separately.
        %
        % @type struct
        EventFuncs
        
    end
    
    
    
    %% methods defined in external files
    methods 
        
        % simulate the dynamical system
        [sol] = simulate(obj, t0, x0, tf, controller, params, eventnames, options)
        
        % check event functions for simulation
        [value, isterminal, direction] = checkGuard(obj, t, x, controller, params, eventfuncs);
        
        % set the mass matrix M(x)
        obj = setMassMatrix(obj, M);
        
        % set the group of drift vector fields F(x) or F(x,dx)
        obj = setDriftVector(obj, vf);
        
        % calculate the mass matrix
        M = calcMassMatrix(obj, x)
        
        % calculate the drift vector
        f = calcDriftVector(obj, x, dx)
        
        % calculate the dynamical equation
        [xdot, extra] = calcDynamics(obj, t, x, controller, params);
        
        % first order system dynamical equation
        [xdot, extra] = firstOrderDynamics(obj, t, x, controller, params);
        
        % second order system dynamical equation
        [xdot, extra] = secondOrderDynamics(obj, t, x, controller, params);
        
        % compile symbolic expression related to the systems
        obj = compile(obj, export_path, varargin);        
        
        % add event functions
        obj = addEvent(obj, constr)
        
        % remove event functions
        obj = removeEvent(obj, name)
        
        % add holonomic constraints
        obj = addHolonomicConstraint(obj, constr);
        
        % remove holonomic constraints
        obj = removeHolonomicConstraint(obj, name);
        
        % add unilateral constraints
        obj = addUnilateralConstraint(obj, name, constr, deps);
        
        % remove unilateral constraints
        obj = removeUnilateralConstraint(obj, name);
        
        % add virtual constraints
        obj = addVirtualConstraint(obj, constr);
        
        % remove virtual constraints
        obj = removeVirtualConstraint(obj, name);
        
        
        
    end
    %% private properties
    properties (Hidden, Access=private)
        
        % The left hand side of the dynamical equation: M(x)dx or M(x)ddx
        %
        % @type SymFunction
        MmatDx
    end
    
    
end

