Prerequestices:
1)Java ;JDK 17 or above 
2)gradle 8 above 
3 minimum 2 gb ram 
steps involved in  gradle installation :
step1:
      JDK installation:
sudo apt install -y openjdk-17-jdk 
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc
source ~/.bashrc

step2: gradle installation:
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 8.4
gradle -v

step3: check the java project gradle folder and versions ; if version not maches delete the files as :
rm -f gradlew.bat
rm -f gradlew
 and then run the below command 
 gradle wrapper --gradle-version 8.5 --distribution-type all
and give the permissions to execute the files 
chmod +x gradlew


and build the jar file 

./gradlew build -->command 

----------------------------------------------------------------------------------------------
for Android mobile applications:

