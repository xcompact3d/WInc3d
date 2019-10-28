module actuator_line_controller

     use decomp_2d, only: mytype, nrank
     use iso_c_binding

implicit none
! Define some parameters
real(mytype), parameter :: OnePlusEps= 1.0 + EPSILON(OnePlusEps)       ! The number slighty greater than unity in single precision.
real(mytype), parameter :: R2D   =  57.295780   ! Factor to convert radians to degrees.
real(mytype), parameter :: RPM2RPS= 9.5492966   ! Factor to convert radians per second to revolutions per minute.


type ControllerType
! Input parameters
real(mytype) :: CornerFreq   =0.0_mytype ! Corner frequency (-3dB point) in the recursive, single-pole,
real(mytype) :: PC_DT        =0.0_mytype ! 0.00125 or JASON:THIS CHANGED FOR ITI BARGE: 0.0001 ! Communication interval for pitch  controller, sec.
real(mytype) :: PC_KI        =0.0_mytype ! Integral gain for pitch controller at rated pitch (zero), (-).
real(mytype) :: PC_KK        =0.0_mytype ! Pitch angle were the derivative of the aerodynamic power
real(mytype) :: PC_KP        =0.0_mytype ! Proportional gain for pitch controller at rated pitch (zero), sec.
real(mytype) :: PC_MaxPit    =0.0_mytype ! Maximum pitch setting in pitch controller, rad.
real(mytype) :: PC_MaxRat    =0.0_mytype ! Maximum pitch  rate (in absolute value) in pitch  controller, rad/s.
real(mytype) :: PC_MinPit    =0.0_mytype ! Minimum pitch setting in pitch controller, rad.
real(mytype) :: PC_RefSpd    =0.0_mytype ! Desired (reference) HSS speed for pitch controller, rad/s.
real(mytype) :: VS_CtInSp    =0.0_mytype ! Transitional generator speed (HSS side) between regions 1 and 1 1/2, rad/s.
real(mytype) :: VS_DT        =0.0_mytype ! JASON:THIS CHANGED FOR ITI BARGE:0.0001 !Communication interval for torque controller, sec.
real(mytype) :: VS_MaxRat    =0.0_mytype ! Maximum torque rate (in absolute value) in torque controller, N-m/s.
real(mytype) :: VS_MaxTq     =0.0_mytype ! Maximum generator torque in Region 3 (HSS side), N-m. -- chosen to be 10% above VS_RtTq = 43.09355kNm
real(mytype) :: VS_Rgn2K     =0.0_mytype ! Generator torque constant in Region 2 (HSS side), N-m/(rad/s)^2.
real(mytype) :: VS_Rgn2Sp    =0.0_mytype ! Transitional generator speed (HSS side) between regions 1 1/2 and 2, rad/s.
real(mytype) :: VS_Rgn3MP    =0.0_mytype ! Minimum pitch angle at which the torque is computed as if we are in region 3 regardless of the generator speed, rad. -- chosen to be 1.0 degree above PC_MinPit
real(mytype) :: VS_RtGnSp    =0.0_mytype ! Rated generator speed (HSS side), rad/s. -- chosen to be 99% of PC_RefSpd
real(mytype) :: VS_RtPwr     =0.0_mytype ! Rated generator power in Region 3, Watts.
real(mytype) :: VS_SlPc      =0.0_mytype ! Rated generator slip percentage in Region 2 1/2, %.
real(mytype) :: GearBoxRatio =0.0_mytype ! Gear Box ratio (usually taken 97:1)
real(mytype) :: IGenerator   =0.0_mytype ! Moment of inertia for the generator

! Local Variables:
real(mytype) :: Alpha       =0.0_mytype           ! Current coefficient in the recursive, single-pole, low-pass filter, (-).
real(mytype) :: BlPitch(3)  =0.0_mytype    ! Current values of the blade pitch angles, rad.
real(mytype) :: ElapTime    =0.0_mytype    ! Elapsed time since the last call to the controller, sec.
real(mytype) :: GenSpeed    =0.0_mytype    ! Current  HSS (generator) speed, rad/s.
real(mytype) :: GenSpeedF   =0.0_mytype    ! Filtered HSS (generator) speed, rad/s.
real(mytype) :: GenTrq      =0.0_mytype    ! Electrical generator torque, N-m.
real(mytype) :: GK          =0.0_mytype    ! Current value of the gain correction factor, used in the gain scheduling law of the pitch controller, (-).
real(mytype) :: HorWindV    =0.0_mytype    ! Horizontal hub-heigh wind speed, m/s.
real(mytype) :: IntSpdErr   =0.0_mytype    ! Current integral of speed error w.r.t. time, rad.
real(mytype) :: LastGenTrq  =0.0_mytype    ! Commanded electrical generator torque the last time the controller was called, N-m.
real(mytype) :: LastTime    =0.0_mytype    ! Last time this contoller was called, sec.
real(mytype) :: LastTimePC  =0.0_mytype    ! Last time the pitch  controller was called, sec.
real(mytype) :: LastTimeVS  =0.0_mytype    ! Last time the torque controller was called, sec.
real(mytype) :: PitCom(3)   =0.0_mytype    ! Commanded pitch of each blade the last time the controller was called, rad.
real(mytype) :: PitComI     =0.0_mytype    ! Integral term of command pitch, rad.
real(mytype) :: PitComP     =0.0_mytype    ! Proportional term of command pitch, rad.
real(mytype) :: PitComT     =0.0_mytype    ! Total command pitch based on the sum of the proportional and integral terms, rad.
real(mytype) :: PitRate(3)  =0.0_mytype    ! Pitch rates of each blade based on the current pitch angles and current pitch command, rad/s.
real(mytype) :: SpdErr      =0.0_mytype    ! Current speed error, rad/s.
real(mytype) :: Time        =0.0_mytype    ! Current simulation time, sec.
real(mytype) :: TrqRate     =0.0_mytype    ! Torque rate based on the current and last torque commands, N-m/s.
real(mytype) :: VS_Slope15  =0.0_mytype    ! Torque/speed slope of region 1 1/2 cut-in torque ramp , N-m/(rad/s).
real(mytype) :: VS_Slope25  =0.0_mytype    ! Torque/speed slope of region 2 1/2 induction generator, N-m/(rad/s).
real(mytype) :: VS_SySp     =0.0_mytype    ! Synchronous speed of region 2 1/2 induction generator, rad/s.
real(mytype) :: VS_TrGnSp   =0.0_mytype    ! Transitional generator speed (HSS side) between regions 2 and 2 1/2, rad/s.
integer :: iStatus              ! A status flag set by the simulation as follows: 0 if this is the first call, 1 for all subsequent time steps, -1 if this is the final call at the end of the simulation.

! pointer to the dll controller call
!PROCEDURE(DISCON), POINTER :: dllpointer ! https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-procedure-pointers
type(c_funptr) :: proc_addr

end type ControllerType

! Interface for the TUM controller
! https://software.intel.com/en-us/fortran-compiler-developer-guide-and-reference-abstract-interface
ABSTRACT INTERFACE
   SUBROUTINE DISCON ( avrSwap, SCoutput, aviFail, accInfile, avcOutname, avcMsg )  BIND(C)
      USE, INTRINSIC :: ISO_C_Binding

      real(c_float), intent(inout), dimension(121) :: avrSwap
      real(c_float), intent(inout), dimension(1) :: SCoutput ! Not used by TUM
      integer :: aviFail! Not used by TUM
      character :: accInfile! Not used by TUM
      character :: avcOutname! Not used by TUM
      character :: avcMsg! Not used by TUM
   END SUBROUTINE DISCON
END INTERFACE

interface
        function dlopen(filename,mode) bind(c,name="dlopen")
            ! void *dlopen(const char *filename, int mode);
            use iso_c_binding
            implicit none
            type(c_ptr) :: dlopen
            character(c_char), intent(in) :: filename(*)
            integer(c_int), value :: mode
        end function

        function dlsym(handle,name) bind(c,name="dlsym")
            ! void *dlsym(void *handle, const char *name);
            use iso_c_binding
            implicit none
            type(c_funptr) :: dlsym
            type(c_ptr), value :: handle
            character(c_char), intent(in) :: name(*)
        end function

        function dlclose(handle) bind(c,name="dlclose")
            ! int dlclose(void *handle);
            use iso_c_binding
            implicit none
            integer(c_int) :: dlclose
            type(c_ptr), value :: handle
        end function
    end interface
contains

subroutine init_controller(control,GeneratorInertia,GBRatio,GBEfficiency,&
                           RatedGenSpeed,RatedLimitGenTorque,CutInGenSpeed,&
                           Region2StartGenSpeed,Region2EndGenSpeed,Kgen,RatedPower,&
                           MaximumTorque)

    implicit none
    ! Read control parameters
    type(ControllerType), intent(inout) :: control
    real(mytype), intent(in) :: GeneratorInertia,GBRatio,GBEfficiency,RatedGenSpeed,RatedLimitGenTorque,CutInGenSpeed
    real(mytype), intent(in) :: Region2StartGenSpeed,Region2EndGenSpeed,Kgen,RatedPower,MaximumTorque
    integer :: AviFail

    control%GearBoxRatio=GBRatio            ! Gear box ratio
    control%IGenerator=GeneratorInertia     ! Moment of Inertia for the Generator
    control%VS_CtInSp=CutInGenSpeed         ! Cut-in speed
    control%VS_RtGnSp=RatedGenSpeed         ! In rad/s
    control%VS_MaxRat=RatedLimitGenTorque   ! Rated limit to Generation Torque
    control%VS_Rgn2K=Kgen                   ! Optimal Curve Coefficient
    control%VS_Rgn2Sp=Region2StartGenSpeed  ! In rad/s
    control%VS_SySp=Region2EndGenSpeed      ! In rad/s
    control%VS_RtPwr=RatedPower             ! Rated generator generator power in Region 3, Watts.
    control%VS_MaxTq=MaximumTorque

    control%CornerFreq=1.570796_mytype   ! Corner frequency (-3dB point) in the recursive, single-pole,
    control%PC_DT=0.00125_mytype         !
    control%PC_KI=0.008068634_mytype     ! Integral gain for pitch controller at rated pitch (zero), (-).
    control%PC_KK=0.1099965_mytype       ! Pitch angle were the derivative of the aerodynamic power
    control%PC_KP= 0.01882681_mytype     ! Proportional gain for pitch controller at rated pitch (zero), sec.
    control%PC_MaxPit = 1.570796_mytype  ! Maximum pitch setting in pitch controller, rad.
    control%PC_MaxRat = 0.1396263_mytype ! Maximum pitch  rate (in absolute value) in pitch  controller, rad/s.
    control%PC_MinPit = 0.0_mytype       ! Minimum pitch setting in pitch controller, rad.
    control%PC_RefSpd = 122.9096_mytype  ! Desired (reference) HSS speed for pitch controller, rad/s.
    control%VS_DT = 0.00125_mytype       ! JASON:THIS CHANGED FOR ITI BARGE:0.0001 !Communication interval for torque controller, sec.
    control%VS_Rgn3MP= 0.01745329_mytype ! Minimum pitch angle at which the torque is computed as if we are in region 3 regardless of the generator speed, rad. -- chosen to be 1.0 degree above PC_MinPit
    control%VS_SlPc=10.0_mytype          ! Rated generator slip percentage in Region 2 1/2, %. -- chosen to be 5MW divided by the electrical generator efficiency of 94.4%

    ! Read input parameters
    ! Determine some torque control parameters not specified directly:
    control%VS_SySp=control%VS_RtGnSp/(1.0+0.01*control%VS_SlPc)
    control%VS_Slope15=(control%VS_Rgn2K*control%VS_Rgn2Sp*control%VS_Rgn2Sp)/(control%VS_Rgn2Sp - control%VS_CtInSp)
    control%VS_Slope25=(control%VS_RtPwr/control%VS_RtGnSp)/(control%VS_RtGnSp-control%VS_SySp)
    if (control%VS_Rgn2K==0.0) then !.TRUE. if the Region 2 torque is flat, and thus, the denominator in the ELSE condition is zero
      control%VS_TrGnSp = control%VS_SySp
    else  ! .TRUE. if the Region 2 torque is quadratic with speed
      control%VS_TrGnSp=(control%VS_Slope25-SQRT(control%VS_Slope25*(control%VS_Slope25-4.0*control%VS_Rgn2K*control%VS_SySp)))/(2.0*control%VS_Rgn2K)
    endif

    AviFail=1

    ! Check validity of input parameters:
    if (control%CornerFreq<= 0.0 )  then
        aviFAIL  = -1
        if (nrank==0) print *,'CornerFreq must be greater than zero.'
    endif
    IF (control%VS_DT<= 0.0 )  THEN
       aviFAIL  = -1
       if (nrank==0)  print *, 'VS_DT must be greater than zero.'
    ENDIF
    IF (control%VS_CtInSp<0.0) THEN
       aviFAIL  = -1
       if (nrank==0)  print *,'VS_CtInSp must not be negative.'
    ENDIF
    IF (control%VS_Rgn2Sp <= control%VS_CtInSp )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_Rgn2Sp must be greater than VS_CtInSp.'
    ENDIF
    IF (control%VS_TrGnSp <  control%VS_Rgn2Sp )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_TrGnSp must not be less than VS_Rgn2Sp.'
    ENDIF
    IF (control%VS_SlPc   <= 0.0 )  THEN
        aviFAIL  = -1
        if (nrank==0) print *,'VS_SlPc must be greater than zero.'
    ENDIF

    IF (control%VS_MaxRat <= 0.0 )  THEN
       aviFAIL  =  -1
       if (nrank==0) print *,'VS_MaxRat must be greater than zero.'
    ENDIF

    IF (control%VS_RtPwr  <  0.0 )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_RtPwr must not be negative.'
    ENDIF

    IF (control%VS_Rgn2K  <  0.0 )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_Rgn2K must not be negative.'
    ENDIF

    IF (control%VS_Rgn2K*control%VS_RtGnSp*control%VS_RtGnSp > control%VS_RtPwr/control%VS_RtGnSp )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_Rgn2K*VS_RtGnSp^2 must not be greater than VS_RtPwr/VS_RtGnSp.'
    ENDIF

    IF (control%VS_MaxTq < control%VS_RtPwr/control%VS_RtGnSp )  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'VS_RtPwr/VS_RtGnSp must not be greater than VS_MaxTq.'
    ENDIF

    IF (control%PC_DT<= 0.0)  THEN
       aviFAIL  = -1
       if (nrank==0) print *,'PC_DT must be greater than zero.'
    ENDIF

    IF (control%PC_KI<= 0.0)  THEN
       aviFAIL  = -1
       if (nrank==0) print*,'PC_KI must be greater than zero.'
    ENDIF

    IF (control%PC_KK<= 0.0)  THEN
       aviFAIL  = -1
       if (nrank==0) print*,'PC_KK must be greater than zero.'
    ENDIF

    IF (control%PC_RefSpd<=0.0)  THEN
       aviFAIL  = -1
       if (nrank==0) print*,'PC_RefSpd must be greater than zero.'
    ENDIF

    IF (control%PC_MaxRat <= 0.0)  THEN
       aviFAIL  = -1
       if (nrank==0) print*,'PC_MaxRat must be greater than zero.'
    ENDIF

    IF (control%PC_MinPit >= control%PC_MaxPit)  THEN
       aviFAIL  = -1
       if (nrank==0) print*,'PC_MinPit must be less than PC_MaxPit.'
    ENDIF

    if (aviFail<0) stop

! Inform users that we are using this user-defined routine:
if(nrank==0) then
print *, '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
print *, 'Running with torque and pitch control of the NREL offshore '
print *, '5MW baseline wind turbine from DISCON.dll as written by J. '
print *, 'Jonkman of NREL/NWTC for use in the IEA Annex XXIII OC3 '
print *, 'studies.'
print *, '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
endif

return

end subroutine init_controller

subroutine operate_controller(control,time,NumBl,rotSpeed)

    implicit none
    type(ControllerType), intent(inout) :: control
   	real(mytype), intent(in) :: time, rotSpeed
    integer,intent(in) :: NumBl
    integer :: k
    ! This Bladed-style DLL controller is used to implement a variable-speed
    ! generator-torque controller and PI collective blade pitch controller for
    ! the NREL Offshore 5MW baseline wind turbine.  This routine was written by
    ! J. Jonkman of NREL/NWTC for use in the IEA Annex XXIII OC3 studies.
    control%GenSpeed=rotSpeed*control%GearBoxRatio

    if(control%iStatus==0) then
    control%GenSpeedF=control%GenSpeed !This will ensure that generator speed filter will use the initial value of the generator speed on the first pass
    control%PitCom=control%BlPitch ! This will ensure that the variable speed controller picks the correct control region and the pitch controller pickes the correct gain on the first call
    control%GK = 1.0/(1.0 + control%PitCom(1)/control%PC_KK) ! This will ensure that the pitch angle is unchanged if the initial SpdErr is zero
    control%IntSpdErr=control%PitCom(1)/(control%GK*control%PC_KI)! This will ensure that the pitch angle is unchanged if the initial SpdErr is zero
    control%LastTime=Time ! This will ensure that generator speed filter will use the initial value of the generator speed on the first pass
    control%LastTimePC=Time-control%PC_DT  ! This will ensure that the pitch  controller is called on the first pass
    control%LastTimeVS =Time-control%VS_DT ! This will ensure that the torque controller is called on the first pass
    endif

    IF (control%iStatus>0)  THEN  ! .TRUE. if were want to do control

    !Main control calculations:
     !========================================================================================
     ! Filter the HSS (generator) speed measurement:
     ! NOTE: This is a very simple recursive, single-pole, low-pass filter with
    !       exponential smoothing.
    ! Update the coefficient in the recursive formula based on the elapsed time
    !   since the last call to the controller:
    control%Alpha= EXP((control%LastTime-Time)*control%CornerFreq)
    ! Apply the filter:
    control%GenSpeedF=(1.0-control%Alpha)*control%GenSpeed+control%Alpha*control%GenSpeedF
    !========================================================================================

    ! Variable-speed torque control:

    ! Compute the elapsed time since the last call to the controller:
    control%ElapTime=Time-control%LastTimeVS

    ! Only perform the control calculations if the elapsed time is greater than
    !   or equal to the communication interval of the torque controller:
    ! NOTE: Time is scaled by OnePlusEps to ensure that the contoller is called
    !       at every time step when VS_DT = DT, even in the presence of
    !       numerical precision errors.


    IF((Time*OnePlusEps-control%LastTimeVS)>=control%VS_DT)  THEN
    ! Compute the generator torque, which depends on which region we are in:
    ! We are in region 3 - power is constant
    IF((control%GenSpeedF>=control%VS_RtGnSp).OR.(control%PitCom(1)>=control%VS_Rgn3MP)) THEN
      control%GenTrq = control%VS_RtPwr/control%GenSpeedF
      if (nrank==0) print *, 'Turbine operates in region 3'
    ELSEIF(control%GenSpeedF<=control%VS_CtInSp)  THEN ! We are in region 1 - torque is zero
      if (nrank==0) print *, 'Turbine operates in region 1'
    control%GenTrq = 0.
    ELSEIF((control%GenSpeedF>control%VS_CtInSp).and.(control%GenSpeedF<control%VS_Rgn2Sp))  THEN  ! We are in region 1 1/2 - linear ramp in torque from zero to optimal
      if (nrank==0) print *, 'Turbine operates in region 1 1/2'
    control%GenTrq = control%VS_Slope15*(control%GenSpeedF-control%VS_CtInSp)
   ELSEIF(control%GenSpeedF<control%VS_TrGnSp)  THEN  ! We are in region 2 - optimal torque is proportional to the square of the generator speed
      if (nrank==0) print *, 'Turbine operates in region 2'
    control%GenTrq=control%VS_Rgn2K*control%GenSpeedF*control%GenSpeedF
   ELSE   ! We are in region 2 1/2 - simple induction generator transition region
      if (nrank==0) print *, 'Turbine operates in region 2 1/2 '
    control%GenTrq=control%VS_Slope25*(control%GenSpeedF-control%VS_SySp)
   ENDIF

   ! Saturate the commanded torque using the maximum torque limit:
    control%GenTrq = MIN(control%GenTrq,control%VS_MaxTq)   ! Saturate the command using the maximum torque limit
   ! Saturate the commanded torque using the torque rate limit:

    if (control%iStatus==0) control%LastGenTrq = control%GenTrq   ! Initialize the value of LastGenTrq on the first pass only
    control%TrqRate=(control%GenTrq-control%LastGenTrq)/control%ElapTime               ! Torque rate (unsaturated)
    control%TrqRate=MIN(MAX(control%TrqRate,-control%VS_MaxRat),control%VS_MaxRat)   ! Saturate the torque rate using its maximum absolute value
    control%GenTrq=control%LastGenTrq+control%TrqRate*control%ElapTime ! Saturate the command using the torque rate limit
    ! Reset the values of LastTimeVS and LastGenTrq to the current values:
    control%LastTimeVS = Time
    control%LastGenTrq = control%GenTrq
    ENDIF
!!=======================================================================


   ! Pitch control:

   ! Compute the elapsed time since the last call to the controller:

   control%ElapTime = time - control%LastTimePC


   ! Only perform the control calculations if the elapsed time is greater than
   !   or equal to the communication interval of the pitch controller:
   ! NOTE: Time is scaled by OnePlusEps to ensure that the contoller is called
   !       at every time step when PC_DT = DT, even in the presence of
   !       numerical precision errors.

   IF ( ( Time*OnePlusEps - control%LastTimePC ) >= control%PC_DT )  THEN
!
!
   ! Compute the gain scheduling correction factor based on the previously
   !   commanded pitch angle for blade 1:

      control%GK = 1.0/( 1.0 + control%PitCom(1)/control%PC_KK)

!
   ! Compute the current speed error and its integral w.r.t. time; saturate the
   ! integral term using the pitch angle limits:

      control%SpdErr    = control%GenSpeedF - control%PC_RefSpd                                 ! Current speed error
      control%IntSpdErr = control%IntSpdErr + control%SpdErr*control%ElapTime                           ! Current integral of speed error w.r.t. time
      control%IntSpdErr = MIN(MAX(control%IntSpdErr,control%PC_MinPit/(control%GK*control%PC_KI)), &
                                  control%PC_MaxPit/(control%GK*control%PC_KI)) ! Saturate the integral term using the pitch angle limits, converted to integral speed error limits

   ! Compute the pitch commands associated with the proportional and integral
   !  gains:

      control%PitComP   = control%GK*control%PC_KP*control%SpdErr               ! Proportional term
      control%PitComI   = control%GK*control%PC_KI*control%IntSpdErr            ! Integral term (saturated)

   ! Superimpose the individual commands to get the total pitch command;
   !  saturate the overall command using the pitch angle limits:

      control%PitComT   = control%PitComP + control%PitComI                                           ! Overall command (unsaturated)
      control%PitComT   = MIN( MAX( control%PitComT, control%PC_MinPit ), control%PC_MaxPit )         ! Saturate the overall command using the pitch angle limits

   ! Saturate the overall commanded pitch using the pitch rate limit:
   ! NOTE: Since the current pitch angle may be different for each blade
   !       (depending on the type of actuator implemented in the structural
   !       dynamics model), this pitch rate limit calculation and the
   !       resulting overall pitch angle command may be different for each
   !       blade.

      DO K = 1,NumBl ! Loop through all blades
         control%PitRate(K) = (control%PitComT - control%BlPitch(K) )/control%ElapTime                 ! Pitch rate of blade K (unsaturated)
         control%PitRate(K) = MIN( MAX( control%PitRate(K), -control%PC_MaxRat ), control%PC_MaxRat)   ! Saturate the pitch rate of blade K using its maximum absolute value
         control%PitCom (K) = control%BlPitch(K) + control%PitRate(K)*control%ElapTime                 ! Saturate the overall command of blade K using the pitch rate limit
         control%BlPitch(K)=control%PitCom(K)
      ENDDO          ! K - all blades

   ! Reset the value of LastTimePC to the current value:

      control%LastTimePC = Time

!   ! Output debugging information if requested:

    !if (nrank==0) then
    !  print *, Time, control%ElapTime, control%GenSpeed/RPM2RPS, control%GenSpeedF/RPM2RPS, control%GenTrq, rotSpeed
    !endif

ENDIF
!
!
!   ! Set the pitch override to yes and command the pitch demanded from the last
!   !   call to the controller (See Appendix A of Bladed User's Guide):
!
!   avrSWAP(55) = 0.0       ! Pitch override: 0=yes
!
!   avrSWAP(42) = PitCom(1) ! Use the command angles of all blades if using individual pitch
!   avrSWAP(43) = PitCom(2) ! "
!   avrSWAP(44) = PitCom(3) ! "
!
!   avrSWAP(45) = PitCom(1) ! Use the command angle of blade 1 if using collective pitch

 ! Reset the value of LastTime to the current value:
    control%LastTime = Time

    endif

    return

end subroutine operate_controller

subroutine init_dllcontroller(controller, controller_file, GearBoxRatio, Igenerator)

    implicit none

    type(ControllerType), intent(inout) :: controller
    character(len=100), intent(in) :: controller_file
    real(mytype), intent(in) :: GearBoxRatio, Igenerator
    type(c_ptr) :: handle
    integer(c_int), parameter :: rtld_lazy=1, rtld_now=2
    !integer :: length

    !length =
    !character(len=) :: controller_file_no_spaces
    !controller_file_no_spaces = controller_file

    controller%GearBoxRatio = GearBoxRatio
    controller%IGenerator = IGenerator

    !print *, "Trying to load:", controller_file
    handle = dlopen(trim(controller_file)//c_null_char, rtld_lazy)
    !handle = dlopen(controller_file//c_null_char, rtld_lazy)
    !handle = dlopen("/home/arturo/technical_work/34-TUM/test_controller/controller/libtest.so"//c_null_char, rtld_lazy)
    !handle = dlopen("./controller/libtest.so"//c_null_char, rtld_lazy)
    if (.not. c_associated(handle))then
        write(*,*) 'Unable to load DLL'
        stop
    end if

    controller%proc_addr = dlsym(handle, "DISCON"//c_null_char)
    if (.not. c_associated(controller%proc_addr))then
        write(*,*) 'Unable to load the procedure DISCON'
        stop
    end if


    if(nrank==0) write (*,*) "Initialising dll controller"
    !print *, "GearBoxRatio:", GearBoxRatio
    !print *, "GeneratorInertia:", controller%IGenerator
    !print *, "library handle:", handle
    !print *, "function address:", controller%proc_addr

end subroutine init_dllcontroller

subroutine dllinterface(proc_addr, meas_pitch, meas_rotVel, meas_power, time, trq_dem, p_com)

    ! https://stackoverflow.com/questions/38710099/fortran-dynamic-libraries-load-at-runtime
    implicit none
    !type(TurbineType), intent(in) :: turb

    type(c_funptr), intent(in) :: proc_addr
    PROCEDURE(DISCON), POINTER :: dllpointer
    real(mytype), intent(in) :: meas_pitch, meas_rotVel, meas_power
    real(mytype), intent(in) :: time
    real(mytype), intent(out) :: trq_dem, p_com
    real(c_float), dimension(121) :: avrSwap = 0.
    real(c_float), dimension(1) :: SCoutput ! Not used by TUM
    integer :: aviFail! Not used by TUM
    character :: accInfile! Not used by TUM
    character :: avcOutname! Not used by TUM
    character :: avcMsg! Not used by TUM

    ! Prepare the input format
    avrSwap(2) = time
    avrSwap(4) = meas_pitch ! Manage the initial twist
    avrSwap(21) = meas_rotVel
    avrSwap(14) = meas_power

    ! Call the controller
    !print *, "Calling the dll controller"
    call c_f_procpointer(proc_addr , dllpointer)
    ! print *, "dllpointer", dllpointer
    call dllpointer(avrSwap, SCoutput, aviFail, accInfile, avcOutname, avcMsg)
    !print *, "End of call to dll controller"

    ! Assign the output
    trq_dem = avrSwap(47)
    p_com = avrSwap(120)
    !p_com = avrSwap[120]
    !p_com = avrSwap[121]

end subroutine dllinterface

end module actuator_line_controller
