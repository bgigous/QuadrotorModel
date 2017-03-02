function [G,Objectives, constraints, hover] = calc_G(penalty, battery, motor, prop, foil, rod, sys)
    
    failure=0;
    climbFailure=0;
    %write prop file for qprop
    write_propfile(prop,foil);
    %calculate hover performance
    [hover] = calc_hover(sys);

    %calculate climb performance
    ClimbVel=10; %velocity requirement for climb: 10 m/s (22 mph)
    [climb] = calc_climb(sys,ClimbVel);

    %Calculation to find out if any of the objective failed
    if isnan(hover.pelec)
        failure=1;
    elseif hover.failure==1
        failure=1;
    elseif climb.failure==1
        failure=1;
    end
    % Calculation of Constraints (only possible with performance data) 
        [constraints]=calc_constraints(battery,motor,prop,foil,rod,sys,hover,failure);
  
    % Calculation of Objectivess
    Objectives.totalCost =sys.cost;
    Objectives.flightTime = battery.Energy /(4*hover.pelec+sys.power); %note: power use is for EACH motor.
    distance= 300; % climb distance in meters--temp, should be specified elsewhere
    time=distance/ClimbVel;
    energy=time*4*(climb.pelec+sys.power);
    Objectives.climbEnergy=time*climb.pelec;

    %Adding Objectivess together...
    multiObjective=Objectives.flightTime+(-Objectives.climbEnergy)/5-3*(Objectives.totalCost);
    
   if failure
        G = penalty.failure;
   else
       check=length(constraints);
        switch(penalty.Mode)
            case 'death' %using the death penalty of G=0 for violated constraints
                death=0;
                  for i=1:check
                      
                    if constraints(i)>0
                       death=1;
                    end     
                  end
                  if death
                      G=penalty.death;
                  else
                      G=(multiObjective);
                  end
            case 'deathplus'
                  death=0;
                    for i=1:check
                        if constraints(i)>0
                            death=1;
                            conRewards(i)=penalty.lin*constraints(i);
                        else
                            conRewards(i)=0;
                        end 
                    end
                         
                  if death
                      G=penalty.death+sum(conRewards);
                  else
                      G=(multiObjective);
                  end
            case 'quad' %using the quadratic penalty method.
               for i=1:check
                    if constraints(i)>0
                        conRewards(i)=-penalty.R*(1+constraints(i))^2;
                    else
                        conRewards(i)=0;
                    end     
               end
                G = max(penalty.quadtrunc,((multiObjective)+sum(conRewards))); 
            case 'const' %using a constant penalty method
               for i=1:check
                    if constraints(i)>0
                        conRewards(i)=-penalty.const;
                    else
                        conRewards(i)=0;
                    end     
               end
                G = max(penalty.quadtrunc,((multiObjective)+sum(conRewards)));
            case 'div' %using a divisive penalty
                for i=1:check
                    if constraints(i)>0
                        conViolation(i)=constraints(i);
                    else
                        conViolation(i)=0;
                    end
                end
                 G=(multiObjective)/(scaleFactor*(1+penalty.div*sum(conViolation)));
               
            case 'divconst'
                for i=1:check
                    if constraints(i)>0
                        conViolation(i)=constraints(i);
                        conRewards(i)=-penalty.const;
                    else
                        conViolation(i)=0;
                        conRewards(i)=0;
                    end
                end
                 G=((multiObjective)/(1+penalty.div*sum(conViolation))+sum(conRewards(i)));
            case 'lin';
                for i=1:check
                    if constraints(i)>0
                        conRewards(i)=penalty.lin*constraints(i)-100;
                    else
                        conRewards(i)=0;
                    end     
               end
                G = ((multiObjective)+sum(conRewards)); 
            case 'none'
                G = (multiObjective);
        end
   end

        %Note: Truncating possible negative performance to just below failure mode.
        %This should help with overly low values of G.
        if G<penalty.failure
            G=1.2*penalty.failure;
        end
end
