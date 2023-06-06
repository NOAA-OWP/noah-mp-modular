module NoahowpmpReadNamelistMod

    use NoahowpmpIOVarType
    use NoahowpmpReadTableModule
  
    implicit none
  
  contains
  
  subroutine NoahowpmpReadNamelist(NoahowpmpIO,namelist_file)

    implicit none
    type(NoahowpmpIO_type), intent(inout)   :: NoahowpmpIO
    character(len=*), intent(in)            :: namelist_file
    integer                                 :: ierr
    character(len=480)                      :: line

    integer            :: ix,iy,iz
    real               :: dt
    character(len=12)  :: startdate
    character(len=12)  :: enddate
    character(len=256) :: forcing_filename
    character(len=256) :: output_filename
    character(len=256) :: parameter_dir
    character(len=256) :: soil_table
    character(len=256) :: veg_class_name
    character(len=256) :: general_table
    character(len=256) :: noahowp_table
    character(len=256) :: soil_class_name
    real               :: lat
    real               :: lon
    real               :: terrain_slope
    real               :: azimuth
    real               :: ZREF               ! measurement height for wind speed (m)
    real               :: rain_snow_thresh

    integer       :: isltyp
    integer       :: nsoil
    integer       :: nsnow
    integer       :: nveg
    real          :: soil_depth
    integer       :: vegtyp
    integer       :: croptype
    integer       :: sfctyp
    integer       :: soilcolor

    real, allocatable, dimension(:) :: zsoil   ! depth of layer-bottom from soil surface
    real, allocatable, dimension(:) :: dzsnso  ! snow/soil layer thickness [m]
    real, allocatable, dimension(:) :: sice    ! soil ice content [m3/m3]
    real, allocatable, dimension(:) :: sh2o    ! soil liquid water content [m3/m3]
    real                            :: zwt     ! initial water table depth [m]

    !--------------------!
    !   model options    !
    !--------------------!
    integer       :: precip_phase_option
    integer       :: runoff_option
    integer       :: drainage_option
    integer       :: frozen_soil_option
    integer       :: dynamic_vic_option
    integer       :: dynamic_veg_option
    integer       :: snow_albedo_option
    integer       :: radiative_transfer_option
    integer       :: sfc_drag_coeff_option
    integer       :: canopy_stom_resist_option
    integer       :: crop_model_option
    integer       :: snowsoil_temp_time_option
    integer       :: soil_temp_boundary_option
    integer       :: supercooled_water_option
    integer       :: stomatal_resistance_option
    integer       :: evap_srfc_resistance_option
    integer       :: subsurface_option
    
    ! ----- END OF VARIABLE DECLARATIONS -------
    
    !--------------------------- !
    !   define namelist groups   !
    !--------------------------- !
    namelist / timing          / dt,startdate,enddate,forcing_filename,output_filename
    namelist / parameters      / parameter_dir, soil_table, general_table, noahowp_table,&
                                 soil_class_name, veg_class_name
    namelist / location        / lat,lon,terrain_slope,azimuth
    namelist / forcing         / ZREF,rain_snow_thresh
    namelist / model_options   / precip_phase_option,runoff_option,drainage_option,frozen_soil_option,&
                                 dynamic_vic_option,dynamic_veg_option,snow_albedo_option,&
                                 radiative_transfer_option,sfc_drag_coeff_option,canopy_stom_resist_option,&
                                 crop_model_option,snowsoil_temp_time_option,soil_temp_boundary_option,&
                                 supercooled_water_option,stomatal_resistance_option,&
                                 evap_srfc_resistance_option,subsurface_option
    namelist / structure       / isltyp,nsoil,nsnow,nveg,vegtyp,croptype,sfctyp,soilcolor
    namelist / initial_values  / zsoil,dzsnso,sice,sh2o,zwt    
    
    ! missing values against which namelist options can be checked
    integer            :: integerMissing
    real               :: realMissing
    character(len=12)  :: stringMissing
    
    ! ----------------------------------------------------------------------------------------------- !
    !   initialize all namelist variables to missing values to allow for checking after namelist read !
    ! ----------------------------------------------------------------------------------------------- !
    integerMissing   = -999999
    realMissing      = -999999.0
    stringMissing    = 'MISSING'
     
    iz               = integerMissing
    dt               = realMissing
    startdate        = stringMissing
    enddate          = stringMissing
    forcing_filename   = stringMissing
    output_filename  = stringMissing
    parameter_dir    = stringMissing
    soil_table       = stringMissing
    veg_class_name   = stringMissing
    general_table    = stringMissing
    noahowp_table    = stringMissing
    soil_class_name  = stringMissing
    lat              = realMissing
    lon              = realMissing
    terrain_slope    = realMissing
    azimuth          = realMissing
    ZREF             = realMissing            
    rain_snow_thresh = realMissing
   
    isltyp           = integerMissing
    nsoil            = integerMissing
    nsnow            = integerMissing
    nveg             = integerMissing
    vegtyp           = integerMissing
    croptype         = integerMissing
    sfctyp           = integerMissing
    soilcolor        = integerMissing
    zwt              = realMissing      

    precip_phase_option         = integerMissing
    runoff_option               = integerMissing
    drainage_option             = integerMissing
    frozen_soil_option          = integerMissing
    dynamic_vic_option          = integerMissing
    dynamic_veg_option          = integerMissing
    snow_albedo_option          = integerMissing
    radiative_transfer_option   = integerMissing
    sfc_drag_coeff_option       = integerMissing
    canopy_stom_resist_option   = integerMissing
    crop_model_option           = integerMissing
    snowsoil_temp_time_option   = integerMissing
    soil_temp_boundary_option   = integerMissing
    supercooled_water_option    = integerMissing
    stomatal_resistance_option  = integerMissing
    evap_srfc_resistance_option = integerMissing
    subsurface_option           = integerMissing

    !---------------------------------------------------------------------
    !  read namelist
    !---------------------------------------------------------------------
    ierr = 0
    if( trim(namelist_file) .ne. '' ) then
      open(30, file=namelist_file, form="formatted", status='old', iostat=ierr)
      if(ierr /= 0) then; write(*,'(A)') 'ERROR: user specified namelist file not found: '//trim(namelist_file); stop; end if
      !print*, 'Reading namelist: ', trim(namelist_file)
    else
      open(30, file='./namelist.input', form="formatted", status='old', iostat=ierr)
      if(ierr /= 0) then; write(*,'(A)') 'ERROR: default namelist file not found: ./namelist.input'; stop; end if
      !print*, 'No namelist filename supplied -- attempting to read namelist.input (default)'
    endif

    read(30, timing, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    read(30, parameters, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    read(30, location, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    read(30, forcing, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    read(30, model_options, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    read(30, structure, iostat=ierr)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      

    !---------------------------------------------------------------------
    !  Check model option validity, part 2
    !---------------------------------------------------------------------
    if (.not. is_within_bound(precip_phase_option, 1, 7)) then; call sys_abort(1,'model options: precip_phase_option should be 1-7'); end if
    if (.not. is_within_bound(runoff_option, 1, 8)) then; call sys_abort(1,'model options: runoff_option should be 1-8'); end if
    if (.not. is_within_bound(drainage_option, 1, 8)) then; call sys_abort(1,'model options: drainage_option should be 1-8'); end if
    if (.not. is_within_bound(frozen_soil_option ,1, 2)) then; call sys_abort(1,'model options: frozen_soil_option should be 1-2'); end if
    if (.not. is_within_bound(dynamic_vic_option ,1, 3)) then; call sys_abort(1,'model options: dynamic_vic_option should be 1-3'); end if
    if (.not. is_within_bound(dynamic_veg_option ,1, 9)) then; call sys_abort(1,'model options: dynamic_veg_option should be 1-9'); end if
    if (.not. is_within_bound(snow_albedo_option ,1, 2)) then; call sys_abort(1,'model options: snow_albedo_option should be 1-2'); end if
    if (.not. is_within_bound(radiative_transfer_option,1, 3)) then; call sys_abort(1,'model options: radiative_transfer_option should be 1-3'); end if
    if (.not. is_within_bound(sfc_drag_coeff_option, 1, 2)) then; call sys_abort(1,'model options: sfc_drag_coeff_option should be 1-3'); end if
    if (.not. is_within_bound(canopy_stom_resist_option, 1, 2)) then; call sys_abort(1,'model options: sfc_drag_coeff_option should be 1-2'); end if
    if (.not. is_within_bound(snowsoil_temp_time_option, 1, 3)) then; call sys_abort(1,'model options: snowsoil_temp_time_option should be 1-3'); end if
    if (.not. is_within_bound(soil_temp_boundary_option, 1, 2)) then; call sys_abort(1,'model options: soil_temp_boundary_option should be 1-2'); end if
    if (.not. is_within_bound(supercooled_water_option, 1, 2)) then; call sys_abort(1,'model options: supercooled_water_option should be 1-2'); end if
    if (.not. is_within_bound(stomatal_resistance_option, 1, 3)) then; call sys_abort(1,'model options: stomatal_resistance_option should be 1-3'); end if
    if (.not. is_within_bound(evap_srfc_resistance_option, 1, 4)) then; call sys_abort(1,'model options: evap_srfc_resistance_option should be 1-4'); end if
    if (.not. is_within_bound(subsurface_option, 1, 3)) then; call sys_abort(1,'model options: subsurface_option should be 1-3'); end if

    !  after reading # of soil layers, allocate local arrays and read soil structure info
    allocate (zsoil (       1:nsoil))   ! depth of layer-bottom from soil surface
    allocate (dzsnso(-nsnow+1:nsoil))   ! snow/soil layer thickness [m]
    allocate (sice  (       1:nsoil))   ! soil ice content [m3/m3]
    allocate (sh2o  (       1:nsoil))   ! soil liquid water content [m3/m3]
    
    ! pre-assign missing values
    sice(1)   = realMissing
    dzsnso(1) = realMissing
    sh2o(1)   = realMissing

    ! read remaining group from namelist
    read(30, initial_values)
    if (ierr/=0) then; backspace(30); read(30,fmt='(A)') line; write(*,'(A)') 'ERROR: invalid line in namelist: '//trim(line); stop; end if      
    close(30)
    
    ! calculate total soil depth and populate array for depth of layer-bottom from soil surface
    if(dzsnso(1) /= realMissing) then
      soil_depth = sum(dzsnso(1:nsoil))
      !soil_depth = 0
      do iz = 1, nsoil
        zsoil(iz) = -1. * sum(dzsnso(1:iz))      
      end do
    else 
      write(*,'(A)') 'ERROR: required entry dzsnso not found in namelist'; stop
    end if 
    
    !---------------------------------------------------------------------
    !  transfer values to namelist data structure
    !---------------------------------------------------------------------
    if(dt               /= realMissing)   then; NoahowpmpIO%dt = dt; else; write(*,'(A)') 'ERROR: required entry dt not found in namelist'; stop; end if 
    if(startdate        /= stringMissing) then; NoahowpmpIO%startdate = startdate; else; write(*,'(A)') 'ERROR: required entry startdate not found in namelist'; stop; end if
    if(enddate          /= stringMissing) then; NoahowpmpIO%enddate = enddate; else; write(*,'(A)') 'ERROR: required entry enddate not found in namelist'; stop; end if
    if(forcing_filename /= stringMissing) then; NoahowpmpIO%forcing_filename = forcing_filename; else; write(*,'(A)') 'ERROR: required entry forcing_filename not found in namelist'; stop; end if
    if(output_filename  /= stringMissing) then; NoahowpmpIO%output_filename = output_filename; else; write(*,'(A)') 'ERROR: required entry output_filename not found in namelist'; stop; end if
    if(parameter_dir    /= stringMissing) then; NoahowpmpIO%parameter_dir = parameter_dir; else; write(*,'(A)') 'ERROR: required entry parameter_dir not found in namelist'; stop; end if
    if(soil_table       /= stringMissing) then; NoahowpmpIO%soil_table = soil_table; else; write(*,'(A)') 'ERROR: required entry soil_table  not found in namelist'; stop; end if
    if(general_table    /= stringMissing) then; NoahowpmpIO%general_table = general_table; else; write(*,'(A)') 'ERROR: required entry general_table not found in namelist'; stop; end if
    if(noahowp_table    /= stringMissing) then; NoahowpmpIO%noahowp_table = noahowp_table; else; write(*,'(A)') 'ERROR: required entry noahowp_table not found in namelist'; stop; end if
    if(soil_class_name  /= stringMissing) then; NoahowpmpIO%soil_class_name = soil_class_name; else; write(*,'(A)') 'ERROR: required entry soil_class_name not found in namelist'; stop; end if
    if(veg_class_name   /= stringMissing) then; NoahowpmpIO%veg_class_name = veg_class_name; else; write(*,'(A)') 'ERROR: required entry veg_class_name not found in namelist'; stop; end if
    
    if(lat              /= realMissing) then; NoahowpmpIO%lat(:,:) = lat; else; write(*,'(A)') 'ERROR: required entry lat not found in namelist'; stop; end if
    if(lon              /= realMissing) then; NoahowpmpIO%lon(:,:) = lon; else; write(*,'(A)') 'ERROR: required entry lon not found in namelist'; stop; end if
    if(terrain_slope    /= realMissing) then; NoahowpmpIO%terrain_slope(:,:) = terrain_slope; else; write(*,'(A)') 'ERROR: required entry terrain_slope not found in namelist'; stop; end if
    if(azimuth          /= realMissing) then; NoahowpmpIO%azimuth(:,:) = azimuth; else; write(*,'(A)') 'ERROR: required entry azimuth not found in namelist'; stop; end if
    if(zref             /= realMissing) then; NoahowpmpIO%ZREF(:,:) = ZREF; else; write(*,'(A)') 'ERROR: required entry ZREF not found in namelist'; stop; end if
    if(rain_snow_thresh /= realMissing) then; NoahowpmpIO%rain_snow_thresh(:,:) = rain_snow_thresh; else; write(*,'(A)') 'ERROR: required entry rain_snow_thresh not found in namelist'; stop; end if

    if(isltyp     /= integerMissing) then; NoahowpmpIO%isltyp(:,:) = isltyp; else; write(*,'(A)') 'ERROR: required entry isltyp not found in namelist'; stop; end if
    if(nsoil      /= integerMissing) then; NoahowpmpIO%nsoil(:,:) = nsoil; else; write(*,'(A)') 'ERROR: required entry nsoil not found in namelist'; stop; end if
    if(nsnow      /= integerMissing) then; NoahowpmpIO%nsnow(:,:) = nsnow; else; write(*,'(A)') 'ERROR: required entry nsnow not found in namelist'; stop; end if
    if(nveg       /= integerMissing) then; NoahowpmpIO%nveg(:,:) = nveg; else; write(*,'(A)') 'ERROR: required entry nveg not found in namelist'; stop; end if
    if(soil_depth /= integerMissing) then; NoahowpmpIO%soil_depth(:,:) = soil_depth; else; write(*,'(A)') 'ERROR: required entry soil_depth not found in namelist'; stop; end if
    if(vegtyp     /= integerMissing) then; NoahowpmpIO%vegtyp(:,:) = vegtyp; else; write(*,'(A)') 'ERROR: required entry vegtyp not found in namelist'; stop; end if
    if(croptype   /= integerMissing) then; NoahowpmpIO%croptype(:,:) = croptype; else; write(*,'(A)') 'ERROR: required entry croptype not found in namelist'; stop; end if
    if(sfctyp     /= integerMissing) then; NoahowpmpIO%sfctyp(:,:) = sfctyp; else; write(*,'(A)') 'ERROR: required entry sfctyp not found in namelist'; stop; end if
    if(soilcolor  /= integerMissing) then; NoahowpmpIO%soilcolor(:,:) = soilcolor; else; write(*,'(A)') 'ERROR: required entry soilcolor not found in namelist'; stop; end if
    if(zwt        /= realMissing) then; NoahowpmpIO%zwt(:,:) = zwt; else; write(*,'(A)') 'ERROR: required entry zwt not found in namelist'; stop; end if

    if(precip_phase_option         /= integerMissing) then; NoahowpmpIO%precip_phase_option(:,:) = precip_phase_option; else; write(*,'(A)') 'ERROR: required entry precip_phase_option not found in namelist'; stop; end if
    if(runoff_option               /= integerMissing) then; NoahowpmpIO%runoff_option(:,:) = runoff_option; else; write(*,'(A)') 'ERROR: required entry runoff_option not found in namelist'; stop; end if
    if(drainage_option             /= integerMissing) then; NoahowpmpIO%drainage_option(:,:) = drainage_option; else; write(*,'(A)') 'ERROR: required entry drainage_option not found in namelist'; stop; end if
    if(frozen_soil_option          /= integerMissing) then; NoahowpmpIO%frozen_soil_option(:,:) = frozen_soil_option; else; write(*,'(A)') 'ERROR: required entry frozen_soil_option not found in namelist'; stop; end if
    if(dynamic_vic_option          /= integerMissing) then; NoahowpmpIO%dynamic_vic_option(:,:) = dynamic_vic_option; else; write(*,'(A)') 'ERROR: required entry dynamic_vic_option not found in namelist'; stop; end if
    if(dynamic_veg_option          /= integerMissing) then; NoahowpmpIO%dynamic_veg_option(:,:) = dynamic_veg_option; else; write(*,'(A)') 'ERROR: required entry dynamic_veg_option not found in namelist'; stop; end if
    if(snow_albedo_option          /= integerMissing) then; NoahowpmpIO%snow_albedo_option(:,:) = snow_albedo_option; else; write(*,'(A)') 'ERROR: required entry snow_albedo_option not found in namelist'; stop; end if
    if(radiative_transfer_option   /= integerMissing) then; NoahowpmpIO%radiative_transfer_option(:,:) = radiative_transfer_option; else; write(*,'(A)') 'ERROR: required entry radiative_transfer_option not found in namelist'; stop; end if
    if(sfc_drag_coeff_option       /= integerMissing) then; NoahowpmpIO%sfc_drag_coeff_option(:,:) = sfc_drag_coeff_option; else; write(*,'(A)') 'ERROR: required entry sfc_drag_coeff_option not found in namelist'; stop; end if
    if(crop_model_option           /= integerMissing) then; NoahowpmpIO%crop_model_option(:,:) = crop_model_option; else; write(*,'(A)') 'ERROR: required entry crop_model_option not found in namelist'; stop; end if
    if(canopy_stom_resist_option   /= integerMissing) then; NoahowpmpIO%canopy_stom_resist_option(:,:) = canopy_stom_resist_option; else; write(*,'(A)') 'ERROR: required entry canopy_stom_resist_option not found in namelist'; stop; end if
    if(snowsoil_temp_time_option   /= integerMissing) then; NoahowpmpIO%snowsoil_temp_time_option(:,:) = snowsoil_temp_time_option; else; write(*,'(A)') 'ERROR: required entry snowsoil_temp_time_option not found in namelist'; stop; end if
    if(soil_temp_boundary_option   /= integerMissing) then; NoahowpmpIO%soil_temp_boundary_option(:,:) = soil_temp_boundary_option; else; write(*,'(A)') 'ERROR: required entry soil_temp_boundary_option not found in namelist'; stop; end if
    if(supercooled_water_option    /= integerMissing) then; NoahowpmpIO%supercooled_water_option(:,:) = supercooled_water_option; else; write(*,'(A)') 'ERROR: required entry supercooled_water_option not found in namelist'; stop; end if
    if(stomatal_resistance_option  /= integerMissing) then; NoahowpmpIO%stomatal_resistance_option(:,:) = stomatal_resistance_option; else; write(*,'(A)') 'ERROR: required entry stomatal_resistance_option not found in namelist'; stop; end if
    if(evap_srfc_resistance_option /= integerMissing) then; NoahowpmpIO%evap_srfc_resistance_option(:,:) = evap_srfc_resistance_option; else; write(*,'(A)') 'ERROR: required entry evap_srfc_resistance_option not found in namelist'; stop; end if
    if(subsurface_option           /= integerMissing) then; NoahowpmpIO%subsurface_option(:,:) = subsurface_option; else; write(*,'(A)') 'ERROR: required entry subsurface_option not found in namelist'; stop; end if
    
    if(zsoil(1).eq.realMissing) write(*,'(A)') 'ERROR: required entry zsoil not found in namelist'; stop
    if(dzsnso(1).eq.realMissing) write(*,'(A)') 'ERROR: required entry dzsnso not found in namelist'; stop
    if(sice(1).eq.realMissing) write(*,'(A)') 'ERROR: required entry sice not found in namelist'; stop
    if(sh2o(1).eq.realMissing) write(*,'(A)') 'ERROR: required entry sh2o not found in namelist'; stop
    do ix = 1, NoahowpmpIO%n_x
      do iy = 1, NoahowpmpIO%n_y
        NoahowpmpIO%zsoil(ix,iy,:) = zsoil
        NoahowpmpIO%dzsnso(ix,iy,:) = dzsnso
        NoahowpmpIO%sice(ix,iy,:) = sice
        NoahowpmpIO%sh2o(ix,iy,:) = sh2o
      end do
    end do

    ! store missing values as well
    NoahowpmpIO%integerMissing              = integerMissing 
    NoahowpmpIO%realMissing                 = realMissing
    NoahowpmpIO%stringMissing               = stringMissing 

    call read_all_parameters(NoahowpmpIO)

  end subroutine

end module NoahowpmpReadNamelistMod