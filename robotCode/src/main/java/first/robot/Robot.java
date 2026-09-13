// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

package first.robot;

import org.wpilib.framework.TimedRobot;
import com.ctre.phoenix6.CANBus;
import com.ctre.phoenix6.configs.TalonFXConfiguration;
import com.ctre.phoenix6.controls.Follower;
import com.ctre.phoenix6.hardware.TalonFX;
import com.ctre.phoenix6.signals.InvertedValue;
import com.ctre.phoenix6.signals.MotorAlignmentValue;
import first.robot.simulation.DrivetrainSim;
import org.wpilib.drive.DifferentialDrive;
import org.wpilib.driverstation.XboxController;
import org.wpilib.framework.OpModeRobot;
import org.wpilib.hardware.imu.OnboardIMU;
import org.wpilib.hardware.imu.OnboardIMU.MountOrientation;

/**
 * The methods in this class are called automatically corresponding to each mode, as described in
 * the TimedRobot documentation. If you change the name of this class or the package after creating
 * this project, you must also update the Main.java file in the project.
 */
public class Robot extends TimedRobot {
  private final int leftLeaderID = 0;
  public TalonFX leftLeader = new TalonFX(leftLeaderID, CANBus.systemcore(0));
  private TalonFX leftFollower = new TalonFX(1, CANBus.systemcore(0));

  private final int rightLeaderID = 2;
  public TalonFX rightLeader = new TalonFX(rightLeaderID, CANBus.systemcore(0));
  private TalonFX rightFollower = new TalonFX(3, CANBus.systemcore(0));

  public final DifferentialDrive drivetrain =
      new DifferentialDrive(leftLeader::setThrottle, rightLeader::setThrottle);

  private OnboardIMU imu = new OnboardIMU(MountOrientation.FLAT);

  private DrivetrainSim drivetrainSim = new DrivetrainSim(leftLeader, rightLeader);

  public TalonFX intakeLauncher = new TalonFX(4, CANBus.systemcore(0));
  public TalonFX feeder = new TalonFX(5, CANBus.systemcore(0));

  private final XboxController xboxController = new XboxController(0);
  /**
   * This function is run when the robot is first started up and should be used for any
   * initialization code.
   */
  public Robot() {
    var leftConfig = new TalonFXConfiguration();
    leftConfig.MotorOutput.withInverted(InvertedValue.Clockwise_Positive);
    leftLeader.getConfigurator().apply(leftConfig);
    leftFollower.getConfigurator().apply(leftConfig);

    leftFollower.setControl(new Follower(leftLeaderID, MotorAlignmentValue.Aligned));

    var rightConfig = new TalonFXConfiguration();
    rightConfig.MotorOutput.withInverted(InvertedValue.CounterClockwise_Positive);
    rightLeader.getConfigurator().apply(rightConfig);
    rightFollower.getConfigurator().apply(rightConfig);

    rightFollower.setControl(new Follower(rightLeaderID, MotorAlignmentValue.Aligned));
  }

  @Override
  public void teleopPeriodic() {
    drivetrain.arcadeDrive(-xboxController.getLeftY(), xboxController.getRightX());

  }

  @Override
  public void simulationPeriodic() {
    drivetrainSim.periodic();
  }

}
