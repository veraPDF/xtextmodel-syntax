package org.verapdf.generator

import com.google.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.verapdf.model.Entity
import org.verapdf.model.Attribute
import org.verapdf.model.Link
import org.verapdf.model.Property
import org.verapdf.model.Import
import java.util.List
import java.util.ArrayList
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.util.RuntimeIOException

/**
 * Generates code from your model files on save.4
 * 
 * see http://www.eclipse.org/Xtext/documentation.html#TutorialCodeGeneration
 */
class ModelGenerator implements IGenerator {
	
	@Inject extension IQualifiedNameProvider

	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		for(e: resource.allContents.toIterable.filter(Entity)) {
			val imports = resource.allContents.toIterable.filter(Import).toList;
			fsa.generateFile(
				e.fullyQualifiedName.toString("/") + ".java",
				compile(e, imports)
			)
		}
		
		val JavaIoFileSystemAccess fsa1 = fsa as JavaIoFileSystemAccess
		
		try{
			val CharSequence is = fsa1.readTextFile("org/verapdf/model/ModelHelper.java")

			var index = is.toString.lastIndexOf('}')
			index = is.toString.substring(0, index).lastIndexOf('}')

			fsa.generateFile(
			"org/verapdf/model/ModelHelper.java",
			is.toString.substring(0,index) + resource.appendDependenceClass			
			)
		}catch(Exception e){
			fsa.generateFile(
			"org/verapdf/model/ModelHelper.java",
			resource.getDependenceClass			
			)
		}
		
		fsa.generateFile(
		"org/verapdf/model/GenericModelObject.java",
		generateGenericModelObject			
		)
		
	}
	
	def compile(Entity entity, List<Import> imports) '''
		«IF entity.eContainer.fullyQualifiedName != null»
			package «entity.eContainer.fullyQualifiedName»;
		
		«ENDIF»
		«FOR imp : imports»
			import «imp.importedNamespace»;
		«ENDFOR»
		«IF entity.superType == null»import java.util.List;«ENDIF»
				
		«IF (entity.comment != null)»
		«toJavaDocComment(entity.comment)»
		«ENDIF»
		public interface «entity.name»«IF entity.superType != null» extends «entity.superType.name»«ENDIF» {
			
			«IF entity.superType == null»
			public List<String> getLinks();
			public List<? extends «entity.name»> getLinkedObjects(String linkName);
			public List<String> getSuperTypes();
			public List<String> getProperties();
			public String getType();
			public String getID();
			public Boolean isContextDependent();
			«ENDIF»
		«FOR attribute : entity.attributes»
		
			«attribute.generateGetter»
		«ENDFOR»
		}
	'''
	
	def generateGetter (Attribute attribute) '''
		«IF (attribute instanceof Property)»
		«IF (attribute.comment != null)»
			«toJavaDocComment(attribute.comment)»
		«ENDIF»
		public «attribute.type» get«attribute.name»();
		«ENDIF»
	'''
	
	def toJavaDocComment (String comment) '''
		/** «comment.substring(1)» */
	'''

	def toInterfaceName (String name) '''I«name»'''
	
/* 		«IF (attribute.any)»
			public List<«attribute.type.name.toInterfaceName»> get«attribute.name»();
		«ENDIF»
		«IF (attribute.zeroOrOne)»
			@Max(1)
			public List<«attribute.type.name.toInterfaceName»> get«attribute.name»();
		«ENDIF»
*/

	def getDependenceClass (Resource resource) '''
		package org.verapdf.model;
		
		import java.util.*;
		
		/**
		* This class represents names of superinterfaces and names of all properties for all generated interfaces.
		*/
		public final class ModelHelper {
			private final static Map<String, String> mapOfSuperNames = new HashMap<String, String>();
			private final static Map<String, List<String>> mapOfProperties = new HashMap<String, List<String>>();
			private final static Map<String, List<String>> mapOfLinks = new HashMap<String, List<String>>();
			private static List<String> properties;
			private static List<String> links;
			
			private ModelHelper(){
				
			}
			
			/**
			* @param objectName - the name of the object
			* @return List of supernames for the given object
			*/
			public static List<String> getListOfSuperNames(String objectName){
				List<String> res = new ArrayList<String>();
				
				String currentObject = mapOfSuperNames.get(objectName);
				
				while(currentObject != null){
					res.add(currentObject);
					currentObject = mapOfSuperNames.get(currentObject);
				}
				
				return res;
			}
			
			/**
			* @param objectName - the name of the object
			* @return List of names of properties for the given object
			*/
			public static List<String> getListOfProperties(String objectName){
				List<String> res = new ArrayList<String>();
				
				String currentObject = objectName;
				
				while(currentObject != null){
					for(String prop : mapOfProperties.get(currentObject)){
						res.add(prop);
					}
					
					currentObject = mapOfSuperNames.get(currentObject);
				}
				
				return res;
			}
			
			/**
			* @param objectName - the name of the object
			* @return List of names of links for the given object
			*/
			public static List<String> getListOfLinks(String objectName){
				List<String> res = new ArrayList<String>();
				
				String currentObject = objectName;
				
				while(currentObject != null){
					for(String link : mapOfLinks.get(currentObject)){
						res.add(link);
					}
					
					currentObject = mapOfSuperNames.get(currentObject);
				}
				
				return res;
			}
		
			static {
		«resource.appendDependenceClass»
	'''
	
	def appendDependenceClass (Resource resource) '''
			
				«FOR e: resource.allContents.toIterable.filter(Entity)»
				mapOfSuperNames.put("«e.name»",«IF e.superType == null»null«ELSE»"«e.superType.name»"«ENDIF»);
				«ENDFOR»
				
				«FOR e: resource.allContents.toIterable.filter(Entity)»
				
				properties = new ArrayList<String>();
				«FOR prop: e.attributes»
					«IF prop instanceof Property»
						properties.add("«prop.name»");
					«ENDIF»
				«ENDFOR»
				mapOfProperties.put("«e.name»",properties);
				«ENDFOR»
				
				«FOR e: resource.allContents.toIterable.filter(Entity)»
				
				links = new ArrayList<String>();
				«FOR link: e.attributes»
					«IF link instanceof Link»
					«IF link.type.name.startsWith("Cos")»
						links.add("«link.name»");
					«ENDIF»
					«ENDIF»
				«ENDFOR»
				mapOfLinks.put("«e.name»",links);
				«ENDFOR»
			}
			
		}
	'''
	
	def generateGenericModelObject() '''
		package org.verapdf.model;
		
		import org.verapdf.model.baselayer.Object;
		import java.util.*;
		
		public abstract class GenericModelObject implements Object {
			
			protected Boolean contextDependent = false;
			
			/**
			* @param link - the name of a link
			* @return List of objects with the given link
			*/
			@Override
			public List<? extends Object> getLinkedObjects(String link) {
		        throw new IllegalAccessError(this.getType() + " has not access to this method or has not " + link + " link.");
		    }
		
			/**
			* @return List of names of links for {@code this} object
			*/
		    @Override
		    public List<String> getLinks() {
		        return ModelHelper.getListOfLinks(this.getType());
		    }
		
			/**
			* @return List of names of properties for {@code this} object
			*/
		    @Override
		    public List<String> getProperties() {
		        return ModelHelper.getListOfProperties(this.getType());
		    }
		
			/**
			* @return null, if we have not know yet is this object context dependet of not. true, if this object is context dependent. false, if this object is not context dependent.
			*/
		    @Override
		    public Boolean isContextDependent() {
		        return contextDependent;
		    }
		
			/**
			* @return List of supernames for {@code this} object
			*/
		    @Override
		    public List<String> getSuperTypes() {
		        return ModelHelper.getListOfSuperNames(this.getType());
		    }
		}
	'''
}